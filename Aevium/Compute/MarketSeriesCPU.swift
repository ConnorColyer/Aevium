import Foundation

struct MarketSeriesAnalytics: Equatable, Sendable {
    let pointCount: Int
    let firstTimestamp: Int64?
    let lastTimestamp: Int64?
    let firstValue: Double
    let lastValue: Double
    let highValue: Double
    let lowValue: Double
    let absoluteChange: Double
    let percentChange: Double
    let sampleCadenceMinutes: Double
    let windowHours: Double
    let averageReturn: Double
    let medianReturn: Double
    let returnStdDev: Double
    let realizedVolPercent: Double
    let averageCandleMovePercent: Double
    let downsideDeviationPercent: Double
    let trendSlopePercentPerStep: Double
    let efficiencyRatio: Double
    let maxDrawdownPercent: Double
    let recoveryPercentFromLow: Double
    let meanPrice: Double
    let medianPrice: Double
    let priceStdDev: Double
    let zScore: Double
    let vwapProxy: Double
    let percentileInRange: Double

    static let empty = MarketSeriesAnalytics(
        pointCount: 0,
        firstTimestamp: nil,
        lastTimestamp: nil,
        firstValue: 0,
        lastValue: 0,
        highValue: 0,
        lowValue: 0,
        absoluteChange: 0,
        percentChange: 0,
        sampleCadenceMinutes: 0,
        windowHours: 0,
        averageReturn: 0,
        medianReturn: 0,
        returnStdDev: 0,
        realizedVolPercent: 0,
        averageCandleMovePercent: 0,
        downsideDeviationPercent: 0,
        trendSlopePercentPerStep: 0,
        efficiencyRatio: 0,
        maxDrawdownPercent: 0,
        recoveryPercentFromLow: 0,
        meanPrice: 0,
        medianPrice: 0,
        priceStdDev: 0,
        zScore: 0,
        vwapProxy: 0,
        percentileInRange: 0
    )

    var volatilityPercent: Double {
        guard lastValue != 0 else { return 0 }
        return ((highValue - lowValue) / abs(lastValue)) * 100
    }

    var distanceToHighPercent: Double {
        (1 - percentileInRange) * 100
    }

    var distanceFromLowPercent: Double {
        percentileInRange * 100
    }
}

enum MarketSeriesCPU {
    private struct LinePointSignature: Hashable {
        let timestamp: Int64
        let source: String
        let resolutionSeconds: Int
    }

    static func deduplicatedLinePoints(_ source: [LinePoint]) -> [LinePoint] {
        guard !source.isEmpty else { return [] }

        let ordered = source.sorted { $0.timestamp < $1.timestamp }
        var results: [LinePoint] = []
        results.reserveCapacity(ordered.count)

        for point in ordered {
            if let lastIndex = results.indices.last, results[lastIndex].timestamp == point.timestamp {
                results[lastIndex] = point
            } else {
                results.append(point)
            }
        }

        return results
    }

    static func sampleLinePointsPreservingExtrema(_ source: [LinePoint], limit: Int) -> [LinePoint] {
        guard source.count > limit, limit > 3 else { return Array(source.prefix(limit)) }
        return sampleOrderedLinePointsPreservingExtrema(source.sorted { $0.timestamp < $1.timestamp }, limit: limit)
    }

    static func sampleLinePointsPreservingExtremaByTime(
        _ source: [LinePoint],
        limit: Int,
        bucketSeconds: Int
    ) -> [LinePoint] {
        guard source.count > limit, limit > 3 else { return Array(source.prefix(limit)) }

        let ordered = source.sorted { $0.timestamp < $1.timestamp }
        let bucketSeconds = max(bucketSeconds, 1)
        var results: [LinePoint] = []
        results.reserveCapacity(limit)

        var bucket: [LinePoint] = []
        var currentBucketStart: Int64?

        func flushBucket() {
            guard !bucket.isEmpty else { return }

            var low = bucket[0]
            var high = bucket[0]

            for point in bucket.dropFirst() {
                if point.price < low.price {
                    low = point
                }
                if point.price > high.price {
                    high = point
                }
            }

            appendIfUniqueTimestamp(bucket[0], to: &results)
            appendIfUniqueTimestamp(low, to: &results)
            appendIfUniqueTimestamp(high, to: &results)
            appendIfUniqueTimestamp(bucket[bucket.count - 1], to: &results)
        }

        for point in ordered {
            let bucketStart = (point.timestamp / Int64(bucketSeconds)) * Int64(bucketSeconds)
            if currentBucketStart == nil {
                currentBucketStart = bucketStart
            }

            if bucketStart != currentBucketStart {
                flushBucket()
                bucket.removeAll(keepingCapacity: true)
                currentBucketStart = bucketStart
            }

            bucket.append(point)
        }

        flushBucket()

        guard results.count > limit else {
            return results
        }

        return sampleOrderedLinePointsPreservingExtrema(results, limit: limit)
    }

    static func sampleOrderedLinePointsPreservingExtrema(_ ordered: [LinePoint], limit: Int) -> [LinePoint] {
        guard ordered.count > limit, limit > 3 else { return Array(ordered.prefix(limit)) }

        let bucketCount = max(1, limit / 4)
        let bucketSize = max(1, Int(ceil(Double(ordered.count) / Double(bucketCount))))

        var results: [LinePoint] = []
        results.reserveCapacity(limit)

        for startIndex in stride(from: 0, to: ordered.count, by: bucketSize) {
            let endIndex = min(startIndex + bucketSize, ordered.count)
            guard startIndex < endIndex else { continue }

            var lowIndex = startIndex
            var highIndex = startIndex

            if startIndex + 1 < endIndex {
                for index in (startIndex + 1)..<endIndex {
                    if ordered[index].price < ordered[lowIndex].price {
                        lowIndex = index
                    }
                    if ordered[index].price > ordered[highIndex].price {
                        highIndex = index
                    }
                }
            }

            var keep: [LinePoint] = [ordered[startIndex]]
            appendIfUniqueTimestamp(ordered[lowIndex], to: &keep)
            appendIfUniqueTimestamp(ordered[highIndex], to: &keep)
            appendIfUniqueTimestamp(ordered[endIndex - 1], to: &keep)

            results.append(contentsOf: keep)
            if results.count >= limit {
                break
            }
        }

        return finalizedSample(results, ordered: ordered, limit: limit)
    }

    static func mergeSorted(existing: [LinePoint], incoming: [LinePoint]) -> [LinePoint] {
        guard !existing.isEmpty else { return incoming }
        guard !incoming.isEmpty else { return existing }

        var merged: [LinePoint] = []
        merged.reserveCapacity(existing.count + incoming.count)

        var existingIndex = 0
        var incomingIndex = 0

        while existingIndex < existing.count || incomingIndex < incoming.count {
            if existingIndex >= existing.count {
                merged.append(incoming[incomingIndex])
                incomingIndex += 1
            } else if incomingIndex >= incoming.count {
                merged.append(existing[existingIndex])
                existingIndex += 1
            } else {
                let existingPoint = existing[existingIndex]
                let incomingPoint = incoming[incomingIndex]

                if existingPoint.timestamp == incomingPoint.timestamp {
                    merged.append(incomingPoint)
                    existingIndex += 1
                    incomingIndex += 1
                } else if existingPoint.timestamp < incomingPoint.timestamp {
                    merged.append(existingPoint)
                    existingIndex += 1
                } else {
                    merged.append(incomingPoint)
                    incomingIndex += 1
                }
            }
        }

        return merged
    }

    static func analytics(for points: [LinePoint]) -> MarketSeriesAnalytics {
        analytics(
            timestamps: points.map(\.timestamp),
            prices: points.map(\.price)
        )
    }

    static func analytics(timestamps: [Int64], prices: [Double]) -> MarketSeriesAnalytics {
        let count = min(timestamps.count, prices.count)
        guard count > 0 else { return .empty }

        let firstTimestamp = timestamps[0]
        let lastTimestamp = timestamps[count - 1]
        let firstValue = prices[0]
        let lastValue = prices[count - 1]

        var lowValue = firstValue
        var highValue = firstValue
        var sum = 0.0
        var sumSquares = 0.0
        var weightedSum = 0.0
        var pathLength = 0.0
        var peak = firstValue
        var worstDrawdown = 0.0
        var returns: [Double] = []
        returns.reserveCapacity(max(count - 1, 0))
        var returnSum = 0.0
        var returnSquares = 0.0
        var absoluteMovePercentSum = 0.0
        var negativeReturnSquares = 0.0
        var negativeReturnCount = 0

        for index in 0..<count {
            let value = prices[index]
            lowValue = min(lowValue, value)
            highValue = max(highValue, value)
            sum += value
            sumSquares += value * value
            weightedSum += value * Double(index + 1)

            peak = max(peak, value)
            if peak != 0 {
                worstDrawdown = min(worstDrawdown, (value - peak) / peak)
            }

            guard index > 0 else { continue }

            let previous = prices[index - 1]
            pathLength += abs(value - previous)

            let safePrevious = max(abs(previous), 0.0001)
            absoluteMovePercentSum += abs(value - previous) / safePrevious

            let priceReturn = previous == 0 ? 0 : (value - previous) / previous
            returns.append(priceReturn)
            returnSum += priceReturn
            returnSquares += priceReturn * priceReturn
            if priceReturn < 0 {
                negativeReturnSquares += priceReturn * priceReturn
                negativeReturnCount += 1
            }
        }

        let absoluteChange = lastValue - firstValue
        let percentChange = firstValue == 0 ? 0 : (absoluteChange / firstValue) * 100
        let meanPrice = sum / Double(count)
        let priceVariance = count > 1
            ? max(0, (sumSquares - (Double(count) * meanPrice * meanPrice)) / Double(count - 1))
            : 0
        let priceStdDev = sqrt(priceVariance)

        let returnCount = returns.count
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
        let sumWeights = Double(count * (count + 1)) / 2
        let vwapProxy = weightedSum / max(sumWeights, 1)
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
            medianPrice: median(Array(prices.prefix(count))),
            priceStdDev: priceStdDev,
            zScore: zScore,
            vwapProxy: vwapProxy,
            percentileInRange: percentileInRange
        )
    }

    static func finalizedSample(_ results: [LinePoint], ordered: [LinePoint], limit: Int) -> [LinePoint] {
        var sampled = results

        if let first = ordered.first, sampled.first?.timestamp != first.timestamp {
            sampled.insert(first, at: 0)
        }
        if let last = ordered.last, sampled.last?.timestamp != last.timestamp {
            sampled.append(last)
        }

        var deduped: [LinePoint] = []
        deduped.reserveCapacity(sampled.count)
        var seen = Set<LinePointSignature>()

        for point in sampled.sorted(by: { $0.timestamp < $1.timestamp }) {
            let signature = LinePointSignature(
                timestamp: point.timestamp,
                source: point.source,
                resolutionSeconds: point.resolutionSeconds
            )
            if seen.insert(signature).inserted {
                deduped.append(point)
            }
            if deduped.count >= limit {
                break
            }
        }

        return deduped
    }

    private static func appendIfUniqueTimestamp(_ point: LinePoint, to keep: inout [LinePoint]) {
        guard !keep.contains(where: { $0.timestamp == point.timestamp }) else { return }
        keep.append(point)
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
