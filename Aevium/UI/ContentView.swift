import SwiftUI
import AppKit
import Charts

struct ContentView: View {
    @State private var selectedRange: ChartRange = .week

    private let points = Self.makeSeries()

    private var visiblePoints: [GraphPoint] {
        selectedRange.slice(from: points)
    }

    private var firstValue: Double { visiblePoints.first?.value ?? 0 }
    private var lastValue: Double { visiblePoints.last?.value ?? 0 }
    private var absoluteChange: Double { lastValue - firstValue }
    private var percentChange: Double {
        guard firstValue != 0 else { return 0 }
        return (absoluteChange / firstValue) * 100
    }
    private var highValue: Double { visiblePoints.map(\.value).max() ?? 0 }
    private var lowValue: Double { visiblePoints.map(\.value).min() ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AmbientBackground(size: proxy.size)
                GrainOverlay()

                AeviumWorkspace(
                    points: visiblePoints,
                    selectedRange: $selectedRange,
                    lastValue: lastValue,
                    highValue: highValue,
                    lowValue: lowValue,
                    percentChange: percentChange,
                    pointCount: visiblePoints.count
                )
            }
            .ignoresSafeArea()
            .background(WindowChromeConfigurator())
        }
    }

    private static func makeSeries(count: Int = 320) -> [GraphPoint] {
        let start = Date().addingTimeInterval(Double(-count * 3600))

        return (0..<count).map { i in
            let p = Double(i) / Double(max(count - 1, 1))
            let trend = 1.8 * sin(p * .pi * 2.4)
            let cycle = 2.9 * cos(p * .pi * 4.8)
            let local = 0.55 * sin(Double(i) * 0.33)
            let lateRecovery = 2.2 * exp(-pow((p - 0.78) / 0.18, 2))

            return GraphPoint(
                index: i,
                date: start.addingTimeInterval(Double(i) * 900),
                value: 141.4 + trend + cycle + local + lateRecovery - p * 1.1
            )
        }
    }
}

private struct AeviumWorkspace: View {
    @State private var isInspectorOpen = true

    let points: [GraphPoint]
    @Binding var selectedRange: ChartRange
    let lastValue: Double
    let highValue: Double
    let lowValue: Double
    let percentChange: Double
    let pointCount: Int

    private var isUp: Bool { percentChange >= 0 }

    var body: some View {
        HStack(spacing: 0) {
            AeviumRail()

            VStack(spacing: 0) {
                WorkspaceTopBar()

                Rectangle()
                    .fill(Color.white.opacity(0.065))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    ChartStage(
                        points: points,
                        selectedRange: $selectedRange,
                        isUp: isUp
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.065))
                        .frame(width: 1)

                    if isInspectorOpen {
                        MarketInspector(
                            isOpen: $isInspectorOpen,
                            lastValue: lastValue,
                            highValue: highValue,
                            lowValue: lowValue,
                            percentChange: percentChange,
                            pointCount: pointCount,
                            isUp: isUp
                        )
                        .frame(width: 286)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        CollapsedInspectorRail(isOpen: $isInspectorOpen)
                            .frame(width: 46)
                            .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isInspectorOpen)
            }
        }
        .background(
            Color(red: 0.105, green: 0.117, blue: 0.130).opacity(0.64)
        )
    }
}

private struct AeviumRail: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 78)

            railButton("chart.xyaxis.line", active: true)
            railButton("tray.full", active: false)
            railButton("waveform.path.ecg", active: false)

            Spacer()

            railButton("slider.horizontal.3", active: false)
        }
        .frame(width: 70)
        .background(Color.black.opacity(0.12))
    }

    private func railButton(_ icon: String, active: Bool) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? Color(red: 0.72, green: 0.88, blue: 0.82) : .white.opacity(0.34))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? Color.white.opacity(0.075) : Color.clear)
                )
                .help(icon)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceTopBar: View {
    var body: some View {
        HStack {
            Text("AEVIUM")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .tracking(3.0)
                .foregroundStyle(.white.opacity(0.52))
            Spacer()
        }
        .padding(.leading, 24)
        .padding(.trailing, 22)
        .frame(height: 44)
    }
}

private struct ChartStage: View {
    let points: [GraphPoint]
    @Binding var selectedRange: ChartRange
    let isUp: Bool
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var yDomain: ClosedRange<Double> {
        let minValue = points.map(\.value).min() ?? 0
        let maxValue = points.map(\.value).max() ?? 1
        let span = max(maxValue - minValue, 1)
        return (minValue - span * 0.10)...(maxValue + span * 0.12)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Chart(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Base", yDomain.lowerBound),
                    yEnd: .value("Price", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.50, green: 0.72, blue: 0.70).opacity(0.20),
                            Color(red: 0.25, green: 0.33, blue: 0.36).opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Price", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    isUp
                        ? Color(red: 0.60, green: 0.86, blue: 0.75)
                        : Color(red: 0.86, green: 0.68, blue: 0.68)
                )

                if let last = points.last {
                    RuleMark(y: .value("Last", last.value))
                        .foregroundStyle(.white.opacity(0.09))
                        .lineStyle(.init(lineWidth: 0.8, dash: [3, 7]))

                    PointMark(
                        x: .value("Time", last.date),
                        y: .value("Price", last.value)
                    )
                    .symbolSize(42)
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: .init(lineWidth: 0.45, dash: [2, 7]))
                        .foregroundStyle(.white.opacity(0.09))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.30))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: .init(lineWidth: 0.4))
                        .foregroundStyle(.white.opacity(0.04))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.30))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                }
            }
            .padding(.top, 44)
            .padding(.leading, 22)
            .padding(.trailing, 18)
            .padding(.bottom, 16)

            AeviumRangeSelector(selectedRange: $selectedRange)
                .padding(.trailing, 24)
                .padding(.top, 14)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.025),
                    Color(red: 0.08, green: 0.12, blue: 0.13).opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func xAxisLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour == 0 {
            return Self.dayFormatter.string(from: date)
        }
        return Self.timeFormatter.string(from: date)
    }
}

private struct AeviumRangeSelector: View {
    @Binding var selectedRange: ChartRange

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(selectedRange == range ? .white.opacity(0.9) : .white.opacity(0.34))
                        .frame(width: 38, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedRange == range ? Color.white.opacity(0.105) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }
}

private struct MarketInspector: View {
    @Binding var isOpen: Bool

    let lastValue: Double
    let highValue: Double
    let lowValue: Double
    let percentChange: Double
    let pointCount: Int
    let isUp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("BTC / USDT")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.86))

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.48, green: 0.85, blue: 0.69))
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }

                    Text(lastValue, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 34, weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.94))

                    Text("\(percentChange >= 0 ? "+" : "")\(percentChange, format: .number.precision(.fractionLength(2)))%")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(isUp ? Color(red: 0.62, green: 0.82, blue: 0.72) : Color(red: 0.86, green: 0.58, blue: 0.58))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        isOpen = false
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                        )
                        .help("Hide inspector")
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            inspectorRows

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("MODEL SIGNALS")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.34))

                signalBar("Flow", value: 0.62, color: Color(red: 0.54, green: 0.78, blue: 0.68))
                signalBar("Stress", value: isUp ? 0.28 : 0.58, color: Color(red: 0.78, green: 0.60, blue: 0.48))
                signalBar("Noise", value: 0.36, color: Color(red: 0.56, green: 0.66, blue: 0.78))
            }

            Spacer()
        }
        .padding(.top, 28)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .background(Color.black.opacity(0.10))
    }

    private var inspectorRows: some View {
        VStack(spacing: 10) {
            metric("Last", lastValue.formatted(.number.precision(.fractionLength(2))))
            metric("Change", "\(percentChange >= 0 ? "+" : "")\(percentChange.formatted(.number.precision(.fractionLength(2))))%")
            metric("High", highValue.formatted(.number.precision(.fractionLength(2))))
            metric("Low", lowValue.formatted(.number.precision(.fractionLength(2))))
            metric("Samples", "\(pointCount)")
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.50))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .default))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func signalBar(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.54))
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.48))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color.opacity(0.76))
                        .frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct CollapsedInspectorRail: View {
    @Binding var isOpen: Bool

    var body: some View {
        VStack {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isOpen = true
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
                    .help("Show inspector")
            }
            .buttonStyle(.plain)
            .padding(.top, 22)

            Spacer()
        }
        .background(Color.black.opacity(0.08))
    }
}

private struct AmbientBackground: View {
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.095, blue: 0.115),
                    Color(red: 0.12, green: 0.135, blue: 0.155),
                    Color(red: 0.075, green: 0.083, blue: 0.093)
                ],
                startPoint: UnitPoint(x: 0.10, y: 0.05),
                endPoint: UnitPoint(x: 0.92, y: 0.95)
            )

            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.16, blue: 0.22).opacity(0.44),
                    Color.clear,
                    Color(red: 0.20, green: 0.13, blue: 0.24).opacity(0.30)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.24, green: 0.42, blue: 0.38).opacity(0.14),
                    .clear
                ],
                center: UnitPoint(x: 0.30, y: 0.72),
                startRadius: 40,
                endRadius: max(size.width, size.height) * 0.78
            )
        }
    }
}

private enum ChartRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"

    var id: String { rawValue }

    var points: Int {
        switch self {
        case .day: return 64
        case .week: return 180
        case .month: return 240
        case .quarter: return 290
        case .year: return 320
        }
    }

    func slice(from data: [GraphPoint]) -> [GraphPoint] {
        Array(data.suffix(min(points, data.count)))
    }
}

private struct GraphPoint: Identifiable {
    let index: Int
    let date: Date
    let value: Double

    var id: Int { index }
}

private struct GrainOverlay: View {
    private static let noiseImage: CGImage = {
        let width = 128
        let height = 128
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        var state: UInt64 = 0xA3_6D_51_9C_2F_B7_E1_44

        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            state = state &* 6364136223846793005 &+ 1
            let n = UInt8((state >> 57) & 0x7F)
            let v = UInt8(108 + Int(n))

            pixels[i] = v
            pixels[i + 1] = v
            pixels[i + 2] = v
            pixels[i + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let provider = CGDataProvider(data: NSData(bytes: &pixels, length: pixels.count))!

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }()

    var body: some View {
        Image(decorative: Self.noiseImage, scale: 1)
            .resizable(resizingMode: .tile)
            .interpolation(.none)
            .blendMode(.softLight)
            .opacity(0.055)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
            context.coordinator.apply()
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(to window: NSWindow?) {
            guard let window else { return }

            let isSameWindow = self.window === window
            self.window = window

            if !isSameWindow {
                for observer in observers {
                    NotificationCenter.default.removeObserver(observer)
                }
                observers.removeAll()

                let names: [Notification.Name] = [
                    NSWindow.didResizeNotification,
                    NSWindow.didMoveNotification,
                    NSWindow.didBecomeMainNotification,
                    NSWindow.didEndLiveResizeNotification
                ]

                for name in names {
                    let token = NotificationCenter.default.addObserver(
                        forName: name,
                        object: window,
                        queue: .main
                    ) { [weak self] _ in
                        self?.apply()
                    }
                    observers.append(token)
                }
            }

            apply()
        }

        func apply() {
            guard let window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)

            guard
                let close = window.standardWindowButton(.closeButton),
                let mini = window.standardWindowButton(.miniaturizeButton),
                let zoom = window.standardWindowButton(.zoomButton),
                let container = close.superview
            else {
                return
            }

            let buttonSize = close.frame.size
            let topInset: CGFloat = 11
            let leadingInset: CGFloat = 6
            let spacing: CGFloat = 8
            let y = container.bounds.height - topInset - buttonSize.height

            close.setFrameOrigin(NSPoint(x: leadingInset, y: y))
            mini.setFrameOrigin(NSPoint(x: leadingInset + buttonSize.width + spacing, y: y))
            zoom.setFrameOrigin(NSPoint(x: leadingInset + (buttonSize.width + spacing) * 2, y: y))
        }
    }
}
