import Foundation
import Metal

enum AeviumComputeOperation: Sendable {
    case sampling
    case analytics
}

struct AeviumMetalCapabilities: Equatable, Sendable {
    enum Tier: String, Sendable {
        case unavailable = "CPU"
        case efficiency = "Efficiency"
        case balanced = "Balanced"
        case performance = "Performance"
        case workstation = "Workstation"
    }

    let deviceName: String
    let tier: Tier
    let hasUnifiedMemory: Bool
    let recommendedWorkingSetGB: Double
    let samplePointThreshold: Int
    let analyticsPointThreshold: Int
    let reductionThreadgroups: Int

    init(
        deviceName: String,
        tier: Tier,
        hasUnifiedMemory: Bool,
        recommendedWorkingSetGB: Double,
        samplePointThreshold: Int,
        analyticsPointThreshold: Int,
        reductionThreadgroups: Int
    ) {
        self.deviceName = deviceName
        self.tier = tier
        self.hasUnifiedMemory = hasUnifiedMemory
        self.recommendedWorkingSetGB = recommendedWorkingSetGB
        self.samplePointThreshold = samplePointThreshold
        self.analyticsPointThreshold = analyticsPointThreshold
        self.reductionThreadgroups = reductionThreadgroups
    }

    static let unavailable = AeviumMetalCapabilities(
        deviceName: "CPU",
        tier: .unavailable,
        hasUnifiedMemory: false,
        recommendedWorkingSetGB: 0,
        samplePointThreshold: Int.max,
        analyticsPointThreshold: Int.max,
        reductionThreadgroups: 1
    )

    init(device: MTLDevice) {
        let lowercasedName = device.name.lowercased()
        let workingSetGB = Double(device.recommendedMaxWorkingSetSize) / 1_073_741_824.0

        let resolvedTier: Tier
        if lowercasedName.contains("ultra") || workingSetGB >= 80 {
            resolvedTier = .workstation
        } else if lowercasedName.contains("max") || workingSetGB >= 48 {
            resolvedTier = .performance
        } else if lowercasedName.contains("pro") || workingSetGB >= 24 {
            resolvedTier = .balanced
        } else {
            resolvedTier = .efficiency
        }

        self.deviceName = device.name
        self.tier = resolvedTier
        self.hasUnifiedMemory = device.hasUnifiedMemory
        self.recommendedWorkingSetGB = workingSetGB

        switch resolvedTier {
        case .unavailable:
            self.samplePointThreshold = Int.max
            self.analyticsPointThreshold = Int.max
            self.reductionThreadgroups = 1
        case .efficiency:
            self.samplePointThreshold = 700
            self.analyticsPointThreshold = 520
            self.reductionThreadgroups = 3
        case .balanced:
            self.samplePointThreshold = 480
            self.analyticsPointThreshold = 360
            self.reductionThreadgroups = 5
        case .performance:
            self.samplePointThreshold = 320
            self.analyticsPointThreshold = 240
            self.reductionThreadgroups = 8
        case .workstation:
            self.samplePointThreshold = 192
            self.analyticsPointThreshold = 160
            self.reductionThreadgroups = 12
        }
    }

    func prefersGPU(pointCount: Int, operation: AeviumComputeOperation) -> Bool {
        guard tier != .unavailable else { return false }

        var multiplier = 1.0
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            break
        case .fair:
            multiplier = 1.20
        case .serious:
            multiplier = 1.65
        case .critical:
            multiplier = 2.40
        @unknown default:
            multiplier = 1.35
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            multiplier *= 1.35
        }

        let baseThreshold = switch operation {
        case .sampling:
            samplePointThreshold
        case .analytics:
            analyticsPointThreshold
        }

        return pointCount >= Int(Double(baseThreshold) * multiplier)
    }
}

struct AeviumComputeSummary: Equatable, Sendable {
    let capabilities: AeviumMetalCapabilities
    let usedGPUForSampling: Bool
    let usedGPUForAnalytics: Bool

    static let cpu = AeviumComputeSummary(
        capabilities: .unavailable,
        usedGPUForSampling: false,
        usedGPUForAnalytics: false
    )

    var label: String {
        if usedGPUForSampling || usedGPUForAnalytics {
            return "Metal \(capabilities.tier.rawValue)"
        }
        return capabilities.tier == .unavailable ? "CPU" : "CPU adaptive"
    }
}

struct MarketSeriesProcessingResult: Sendable {
    let points: [LinePoint]
    let analytics: MarketSeriesAnalytics
    let computeSummary: AeviumComputeSummary
}

actor MarketSeriesProcessor {
    private let gpu: AeviumMetalSeriesGPU?

    init() {
        self.gpu = AeviumMetalSeriesGPU()
    }

    var capabilities: AeviumMetalCapabilities {
        gpu?.capabilities ?? .unavailable
    }

    func process(existing: [LinePoint], incoming: [LinePoint], cap: Int) -> MarketSeriesProcessingResult {
        let sanitizedIncoming = cleanedLinePointsForDisplay(incoming)
        let incomingSample = sample(sanitizedIncoming, limit: cap)

        let nextPoints: [LinePoint]
        let usedGPUForSampling: Bool
        if existing.isEmpty {
            nextPoints = incomingSample.points
            usedGPUForSampling = incomingSample.usedGPU
        } else {
            let merged = MarketSeriesCPU.mergeSorted(existing: existing, incoming: incomingSample.points)
            let deduped = cleanedLinePointsForDisplay(merged)
            let finalSample = sample(deduped, limit: cap)
            nextPoints = finalSample.points
            usedGPUForSampling = incomingSample.usedGPU || finalSample.usedGPU
        }

        let analyticsResult = analytics(for: nextPoints)
        let summary = AeviumComputeSummary(
            capabilities: capabilities,
            usedGPUForSampling: usedGPUForSampling,
            usedGPUForAnalytics: analyticsResult.usedGPU
        )

        return MarketSeriesProcessingResult(
            points: nextPoints,
            analytics: analyticsResult.analytics,
            computeSummary: summary
        )
    }

    func processSnapshot(
        points: [LinePoint],
        cap: Int,
        stableBucketSeconds: Int
    ) -> MarketSeriesProcessingResult {
        let sanitized = cleanedLinePointsForDisplay(points)
        let sampled = sample(sanitized, limit: cap, stableBucketSeconds: stableBucketSeconds)
        let analyticsResult = analytics(for: sampled.points)
        let summary = AeviumComputeSummary(
            capabilities: capabilities,
            usedGPUForSampling: sampled.usedGPU,
            usedGPUForAnalytics: analyticsResult.usedGPU
        )

        return MarketSeriesProcessingResult(
            points: sampled.points,
            analytics: analyticsResult.analytics,
            computeSummary: summary
        )
    }

    func analyticsOnly(for points: [LinePoint]) -> MarketSeriesProcessingResult {
        let analyticsResult = analytics(for: points)
        let summary = AeviumComputeSummary(
            capabilities: capabilities,
            usedGPUForSampling: false,
            usedGPUForAnalytics: analyticsResult.usedGPU
        )

        return MarketSeriesProcessingResult(
            points: points,
            analytics: analyticsResult.analytics,
            computeSummary: summary
        )
    }

    private func sample(_ points: [LinePoint], limit: Int) -> (points: [LinePoint], usedGPU: Bool) {
        guard points.count > limit, limit > 3 else {
            return (Array(points.prefix(limit)), false)
        }

        let ordered = points.sorted { $0.timestamp < $1.timestamp }
        if
            let gpu,
            capabilities.prefersGPU(pointCount: ordered.count, operation: .sampling),
            let sampled = gpu.sampleExtrema(ordered: ordered, limit: limit)
        {
            return (sampled, true)
        }

        return (MarketSeriesCPU.sampleOrderedLinePointsPreservingExtrema(ordered, limit: limit), false)
    }

    private func sample(
        _ points: [LinePoint],
        limit: Int,
        stableBucketSeconds: Int
    ) -> (points: [LinePoint], usedGPU: Bool) {
        guard points.count > limit, limit > 3 else {
            return (Array(points.prefix(limit)), false)
        }

        return (
            MarketSeriesCPU.sampleLinePointsPreservingExtremaByTime(
                points,
                limit: limit,
                bucketSeconds: stableBucketSeconds
            ),
            false
        )
    }

    private func analytics(for points: [LinePoint]) -> (analytics: MarketSeriesAnalytics, usedGPU: Bool) {
        if
            let gpu,
            capabilities.prefersGPU(pointCount: points.count, operation: .analytics),
            let analytics = gpu.analytics(for: points)
        {
            return (analytics, true)
        }

        return (MarketSeriesCPU.analytics(for: points), false)
    }
}

private final class AeviumMetalSeriesGPU {
    let capabilities: AeviumMetalCapabilities

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bucketPipeline: MTLComputePipelineState
    private let analyticsPipeline: MTLComputePipelineState
    private let analyticsThreadgroupSize = 256

    init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            device.hasUnifiedMemory,
            let commandQueue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let bucketFunction = library.makeFunction(name: "aevium_bucket_extrema"),
            let analyticsFunction = library.makeFunction(name: "aevium_series_partials")
        else {
            return nil
        }

        let bucketPipeline: MTLComputePipelineState
        let analyticsPipeline: MTLComputePipelineState
        do {
            bucketPipeline = try device.makeComputePipelineState(function: bucketFunction)
            analyticsPipeline = try device.makeComputePipelineState(function: analyticsFunction)
        } catch {
            return nil
        }

        guard analyticsPipeline.maxTotalThreadsPerThreadgroup >= analyticsThreadgroupSize else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.bucketPipeline = bucketPipeline
        self.analyticsPipeline = analyticsPipeline
        self.capabilities = AeviumMetalCapabilities(device: device)
    }

    func sampleExtrema(ordered: [LinePoint], limit: Int) -> [LinePoint]? {
        guard ordered.count > limit, limit > 3 else { return Array(ordered.prefix(limit)) }

        let bucketCount = max(1, limit / 4)
        let bucketSize = max(1, Int(ceil(Double(ordered.count) / Double(bucketCount))))
        let prices = ordered.map { Float($0.price) }

        guard
            let priceBuffer = device.makeBuffer(
                bytes: prices,
                length: MemoryLayout<Float>.stride * prices.count,
                options: .storageModeShared
            )
        else {
            return nil
        }

        var uniforms = BucketExtremaUniforms(
            pointCount: UInt32(ordered.count),
            bucketSize: UInt32(bucketSize),
            bucketCount: UInt32(bucketCount),
            padding: 0
        )

        guard
            let uniformBuffer = device.makeBuffer(
                bytes: &uniforms,
                length: MemoryLayout<BucketExtremaUniforms>.stride,
                options: .storageModeShared
            ),
            let resultBuffer = device.makeBuffer(
                length: MemoryLayout<BucketExtremaResult>.stride * bucketCount,
                options: .storageModeShared
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(bucketPipeline)
        encoder.setBuffer(priceBuffer, offset: 0, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setBuffer(resultBuffer, offset: 0, index: 2)

        let threadgroupWidth = max(
            1,
            min(bucketCount, bucketPipeline.threadExecutionWidth, bucketPipeline.maxTotalThreadsPerThreadgroup)
        )
        encoder.dispatchThreads(
            MTLSize(width: bucketCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed else { return nil }

        let pointer = resultBuffer.contents().bindMemory(
            to: BucketExtremaResult.self,
            capacity: bucketCount
        )
        let bucketResults = UnsafeBufferPointer(start: pointer, count: bucketCount)

        var sampled: [LinePoint] = []
        sampled.reserveCapacity(limit)

        for bucket in bucketResults {
            let indices = [
                Int(bucket.firstIndex),
                Int(bucket.lowIndex),
                Int(bucket.highIndex),
                Int(bucket.lastIndex)
            ]

            var keep: [LinePoint] = []
            keep.reserveCapacity(4)
            for index in indices where index >= 0 && index < ordered.count {
                let point = ordered[index]
                guard !keep.contains(where: { $0.timestamp == point.timestamp }) else { continue }
                keep.append(point)
            }

            sampled.append(contentsOf: keep)
            if sampled.count >= limit {
                break
            }
        }

        return MarketSeriesCPU.finalizedSample(sampled, ordered: ordered, limit: limit)
    }

    func analytics(for points: [LinePoint]) -> MarketSeriesAnalytics? {
        guard points.count > 1 else { return MarketSeriesCPU.analytics(for: points) }

        let count = points.count
        let prices = points.map { Float($0.price) }
        let groupCount = min(
            max(1, (count + analyticsThreadgroupSize - 1) / analyticsThreadgroupSize),
            capabilities.reductionThreadgroups
        )
        let totalThreads = groupCount * analyticsThreadgroupSize

        guard
            let priceBuffer = device.makeBuffer(
                bytes: prices,
                length: MemoryLayout<Float>.stride * prices.count,
                options: .storageModeShared
            )
        else {
            return nil
        }

        var uniforms = AnalyticsUniforms(
            pointCount: UInt32(count),
            threadsPerGrid: UInt32(totalThreads),
            padding0: 0,
            padding1: 0
        )

        guard
            let uniformBuffer = device.makeBuffer(
                bytes: &uniforms,
                length: MemoryLayout<AnalyticsUniforms>.stride,
                options: .storageModeShared
            ),
            let partialBuffer = device.makeBuffer(
                length: MemoryLayout<AnalyticsPartial>.stride * groupCount,
                options: .storageModeShared
            ),
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return nil
        }

        encoder.setComputePipelineState(analyticsPipeline)
        encoder.setBuffer(priceBuffer, offset: 0, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setBuffer(partialBuffer, offset: 0, index: 2)
        encoder.dispatchThreads(
            MTLSize(width: totalThreads, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: analyticsThreadgroupSize, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed else { return nil }

        let partialPointer = partialBuffer.contents().bindMemory(
            to: AnalyticsPartial.self,
            capacity: groupCount
        )
        let partials = UnsafeBufferPointer(start: partialPointer, count: groupCount)
        return makeAnalytics(points: points, partials: partials)
    }

    private func makeAnalytics(
        points: [LinePoint],
        partials: UnsafeBufferPointer<AnalyticsPartial>
    ) -> MarketSeriesAnalytics {
        let count = points.count
        let firstTimestamp = points[0].timestamp
        let lastTimestamp = points[count - 1].timestamp
        let firstValue = points[0].price
        let lastValue = points[count - 1].price

        var lowValue = Double.greatestFiniteMagnitude
        var highValue = -Double.greatestFiniteMagnitude
        var sum = 0.0
        var sumSquares = 0.0
        var weightedSum = 0.0
        var returnSum = 0.0
        var returnSquares = 0.0
        var negativeReturnSquares = 0.0
        var absoluteMovePercentSum = 0.0
        var pathLength = 0.0
        var returnCount = 0
        var negativeReturnCount = 0

        for partial in partials {
            lowValue = min(lowValue, Double(partial.minPrice))
            highValue = max(highValue, Double(partial.maxPrice))
            sum += Double(partial.sumPrice)
            sumSquares += Double(partial.sumSquares)
            weightedSum += Double(partial.weightedPriceSum)
            returnSum += Double(partial.returnSum)
            returnSquares += Double(partial.returnSquares)
            negativeReturnSquares += Double(partial.negativeReturnSquares)
            absoluteMovePercentSum += Double(partial.absoluteMovePercentSum)
            pathLength += Double(partial.pathLength)
            returnCount += Int(partial.returnCount)
            negativeReturnCount += Int(partial.negativeReturnCount)
        }

        var peak = firstValue
        var worstDrawdown = 0.0
        var prices: [Double] = []
        prices.reserveCapacity(count)
        var returns: [Double] = []
        returns.reserveCapacity(max(count - 1, 0))

        for index in 0..<count {
            let value = points[index].price
            prices.append(value)
            peak = max(peak, value)
            if peak != 0 {
                worstDrawdown = min(worstDrawdown, (value - peak) / peak)
            }

            if index > 0 {
                let previous = points[index - 1].price
                returns.append(previous == 0 ? 0 : (value - previous) / previous)
            }
        }

        let absoluteChange = lastValue - firstValue
        let percentChange = firstValue == 0 ? 0 : (absoluteChange / firstValue) * 100
        let meanPrice = sum / Double(count)
        let priceVariance = count > 1
            ? max(0, (sumSquares - (Double(count) * meanPrice * meanPrice)) / Double(count - 1))
            : 0
        let priceStdDev = sqrt(priceVariance)
        let averageReturn = returnCount > 0 ? returnSum / Double(returnCount) : 0
        let returnVariance = returnCount > 1
            ? max(0, (returnSquares - (Double(returnCount) * averageReturn * averageReturn)) / Double(returnCount - 1))
            : 0
        let returnStdDev = sqrt(returnVariance)
        let realizedVolPercent = returnStdDev * sqrt(Double(max(returnCount, 1))) * 100
        let averageCandleMovePercent = returnCount > 0
            ? (absoluteMovePercentSum / Double(returnCount)) * 100
            : 0
        let downsideDeviationPercent = negativeReturnCount > 0
            ? sqrt(negativeReturnSquares / Double(negativeReturnCount)) * 100
            : 0
        let trendSlopePercentPerStep = count > 1
            ? ((lastValue - firstValue) / max(abs(firstValue), 0.0001)) / Double(count - 1) * 100
            : 0
        let efficiencyRatio = pathLength > 0
            ? abs(lastValue - firstValue) / pathLength
            : 0
        let recoveryPercentFromLow = lowValue != 0
            ? max(0, (lastValue - lowValue) / abs(lowValue) * 100)
            : 0
        let vwapProxy = weightedSum / max(Double(count * (count + 1)) / 2, 1)
        let zScore = priceStdDev > 0 ? (lastValue - meanPrice) / priceStdDev : 0
        let span = max(highValue - lowValue, 0.0001)
        let percentileInRange = ((lastValue - lowValue) / span).clamped(to: 0...1)
        let windowMinutes = Double(lastTimestamp - firstTimestamp) / 60
        let sampleCadenceMinutes = count > 1 ? windowMinutes / Double(count - 1) : 0

        return MarketSeriesAnalytics(
            pointCount: count,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            firstValue: firstValue,
            lastValue: lastValue,
            highValue: highValue,
            lowValue: lowValue,
            absoluteChange: absoluteChange,
            percentChange: percentChange,
            sampleCadenceMinutes: sampleCadenceMinutes,
            windowHours: Double(lastTimestamp - firstTimestamp) / 3600,
            averageReturn: averageReturn,
            medianReturn: median(returns),
            returnStdDev: returnStdDev,
            realizedVolPercent: realizedVolPercent,
            averageCandleMovePercent: averageCandleMovePercent,
            downsideDeviationPercent: downsideDeviationPercent,
            trendSlopePercentPerStep: trendSlopePercentPerStep,
            efficiencyRatio: efficiencyRatio,
            maxDrawdownPercent: abs(worstDrawdown * 100),
            recoveryPercentFromLow: recoveryPercentFromLow,
            meanPrice: meanPrice,
            medianPrice: median(prices),
            priceStdDev: priceStdDev,
            zScore: zScore,
            vwapProxy: vwapProxy,
            percentileInRange: percentileInRange
        )
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}

private struct BucketExtremaUniforms {
    var pointCount: UInt32
    var bucketSize: UInt32
    var bucketCount: UInt32
    var padding: UInt32
}

private struct BucketExtremaResult {
    var firstIndex: UInt32
    var lowIndex: UInt32
    var highIndex: UInt32
    var lastIndex: UInt32
}

private struct AnalyticsUniforms {
    var pointCount: UInt32
    var threadsPerGrid: UInt32
    var padding0: UInt32
    var padding1: UInt32
}

private struct AnalyticsPartial {
    var minPrice: Float
    var maxPrice: Float
    var sumPrice: Float
    var sumSquares: Float
    var weightedPriceSum: Float
    var returnSum: Float
    var returnSquares: Float
    var negativeReturnSquares: Float
    var absoluteMovePercentSum: Float
    var pathLength: Float
    var returnCount: UInt32
    var negativeReturnCount: UInt32
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
