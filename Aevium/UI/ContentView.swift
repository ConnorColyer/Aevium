import SwiftUI
import AppKit
import Charts

struct ContentView: View {
    @State private var points = Self.makeSeries()
    @State private var selectedRange: ChartRange = .week
    @State private var isInfoOpen = true

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
    private var isUptrend: Bool { absoluteChange >= 0 }
    private var dayHigh: Double { visiblePoints.map(\.value).max() ?? 0 }
    private var dayLow: Double { visiblePoints.map(\.value).min() ?? 0 }

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let size = proxy.size
                let t = context.date.timeIntervalSinceReferenceDate
                let baseStart = UnitPoint(
                    x: 0.12 + 0.03 * sin(t * 0.045),
                    y: 0.10 + 0.025 * cos(t * 0.040)
                )
                let baseEnd = UnitPoint(
                    x: 0.88 + 0.03 * cos(t * 0.038),
                    y: 0.90 + 0.025 * sin(t * 0.042)
                )

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.18, blue: 0.20),
                            Color(red: 0.13, green: 0.14, blue: 0.155),
                            Color(red: 0.095, green: 0.102, blue: 0.116)
                        ],
                        startPoint: baseStart,
                        endPoint: baseEnd
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 0.24, green: 0.36, blue: 0.51).opacity(0.22),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.35 + 0.08 * sin(t * 0.11),
                            y: 0.30 + 0.07 * cos(t * 0.09)
                        ),
                        startRadius: 20,
                        endRadius: min(size.width, size.height) * 0.75
                    )

                    RadialGradient(
                        colors: [
                            Color(red: 0.19, green: 0.35, blue: 0.31).opacity(0.21),
                            .clear
                        ],
                        center: UnitPoint(
                            x: 0.70 + 0.07 * cos(t * 0.10),
                            y: 0.65 + 0.08 * sin(t * 0.12)
                        ),
                        startRadius: 20,
                        endRadius: min(size.width, size.height) * 0.80
                    )

                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.13, blue: 0.12).opacity(0.16),
                            Color.clear,
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Rectangle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    .clear,
                                    Color(red: 0.21, green: 0.31, blue: 0.46).opacity(0.10),
                                    .clear,
                                    Color(red: 0.18, green: 0.32, blue: 0.28).opacity(0.08),
                                    .clear
                                ],
                                center: .center
                            )
                        )
                        .rotationEffect(.degrees((t * 1.5).truncatingRemainder(dividingBy: 360)))
                        .blur(radius: 110)
                        .blendMode(.softLight)
                        .opacity(0.13 + 0.02 * sin(t * 0.06))
                        .allowsHitTesting(false)

                    GrainOverlay()

                    let drawerWidth = min(320, max(278, size.width * 0.19))

                    FocusedPriceGraph(
                        points: visiblePoints,
                        time: t,
                        isUptrend: isUptrend
                    )
                    .padding(.leading, 14)
                    .padding(.top, 50)
                    .padding(.bottom, 14)
                    .padding(.trailing, isInfoOpen ? drawerWidth + 26 : 20)
                    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isInfoOpen)

                    HStack(spacing: 0) {
                        Spacer()

                        if isInfoOpen {
                            SideInfoPanel(
                                lastValue: lastValue,
                                percentChange: percentChange,
                                high: dayHigh,
                                low: dayLow,
                                volume: Double(visiblePoints.count) * 97.3,
                                absoluteChange: absoluteChange,
                                pointsCount: visiblePoints.count
                            )
                            .frame(width: drawerWidth)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial.opacity(0.32))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.24), radius: 18, x: -2, y: 10)
                            .padding(.trailing, 12)
                            .padding(.vertical, 16)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isInfoOpen)

                    if !isInfoOpen {
                        VStack {
                            HStack {
                                Spacer()
                                FloatingPriceTicker(
                                    isOpen: $isInfoOpen,
                                    symbol: "BTC / USDT",
                                    lastValue: lastValue,
                                    percentChange: percentChange,
                                    isUptrend: isUptrend
                                )
                                .padding(.trailing, 24)
                                .padding(.top, 68)
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    VStack {
                        HStack {
                            Spacer()
                            InfoDrawerTab(isOpen: $isInfoOpen)
                                .padding(.top, 16)
                                .padding(.trailing, 18)
                        }
                        Spacer()
                    }
                }
                .ignoresSafeArea()
                .background(WindowChromeConfigurator())
            }
        }
    }

    private static func makeSeries(count: Int = 320) -> [GraphPoint] {
        let start = Date().addingTimeInterval(Double(-count * 3600))
        var value: Double = 138.0
        var output: [GraphPoint] = []
        output.reserveCapacity(count)

        for i in 0..<count {
            let swing = sin(Double(i) * 0.055) * 1.35
            let drift = cos(Double(i) * 0.017) * 0.34
            let micro = sin(Double(i) * 0.42) * 0.16
            value += swing * 0.12 + drift * 0.08 + micro

            output.append(
                GraphPoint(
                    index: i,
                    date: start.addingTimeInterval(Double(i) * 3600),
                    value: value
                )
            )
        }

        return output
    }
}

private struct InfoDrawerTab: View {
    @Binding var isOpen: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                isOpen.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 11, weight: .semibold))
                Text(isOpen ? "Hide Info" : "Show Info")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                Image(systemName: isOpen ? "chevron.right" : "chevron.left")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.76))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.52))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FloatingPriceTicker: View {
    @Binding var isOpen: Bool
    let symbol: String
    let lastValue: Double
    let percentChange: Double
    let isUptrend: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                isOpen = true
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        isUptrend
                            ? Color(red: 0.72, green: 0.86, blue: 0.83)
                            : Color(red: 0.90, green: 0.69, blue: 0.72)
                    )
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(lastValue, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.96))
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundStyle(.white.opacity(0.44))
                    Text("\(percentChange >= 0 ? "+" : "")\(percentChange, format: .number.precision(.fractionLength(2)))%")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(
                            isUptrend
                                ? Color(red: 0.72, green: 0.86, blue: 0.83)
                                : Color(red: 0.90, green: 0.69, blue: 0.72)
                        )
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.24), radius: 12, x: 0, y: 7)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(
                        .white.opacity(0.56)
                    )
                    .padding(.trailing, 8)
            }
        }
        .buttonStyle(.plain)
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
        case .day: return 24
        case .week: return 24 * 7
        case .month: return 24 * 30
        case .quarter: return 24 * 90
        case .year: return 24 * 300
        }
    }

    func slice(from data: [GraphPoint]) -> [GraphPoint] {
        let count = min(points, data.count)
        return Array(data.suffix(count))
    }
}

private struct GraphPoint: Identifiable {
    let index: Int
    let date: Date
    let value: Double

    var id: Int { index }
}

private struct FocusedPriceGraph: View {
    let points: [GraphPoint]
    let time: TimeInterval
    let isUptrend: Bool

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Time", point.date),
                y: .value("Price", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.64, blue: 0.82).opacity(0.15),
                        Color(red: 0.38, green: 0.54, blue: 0.70).opacity(0.08),
                        Color.clear
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
            .lineStyle(.init(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        isUptrend
                            ? Color(red: 0.76, green: 0.84, blue: 0.94)
                            : Color(red: 0.91, green: 0.71, blue: 0.73),
                        isUptrend
                            ? Color(red: 0.64, green: 0.77, blue: 0.89)
                            : Color(red: 0.86, green: 0.63, blue: 0.66)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            if let last = points.last {
                PointMark(
                    x: .value("Time", last.date),
                    y: .value("Price", last.value)
                )
                .symbolSize(52)
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.45, dash: [2.5, 4]))
                    .foregroundStyle(.white.opacity(0.12))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.34))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.4))
                    .foregroundStyle(.white.opacity(0.04))
                AxisTick(stroke: .init(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.20))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.34))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color.clear)
        }
        .overlay(alignment: .topTrailing) {
            if let last = points.last {
                Text(last.value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.56))
                    .padding(.top, 2)
                    .padding(.trailing, 6)
            }
        }
    }
}

private struct SideInfoPanel: View {
    let lastValue: Double
    let percentChange: Double
    let high: Double
    let low: Double
    let volume: Double
    let absoluteChange: Double
    let pointsCount: Int

    private var isUptrend: Bool { absoluteChange >= 0 }
    private var confidence: Double { min(97, max(3, 50 + absoluteChange * 1.8)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("$ \(Int(lastValue))")
                    .font(.system(size: 50, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                Text("\(absoluteChange >= 0 ? "+" : "")\(percentChange, format: .number.precision(.fractionLength(2)))%")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(
                        isUptrend
                            ? Color(red: 0.72, green: 0.86, blue: 0.83)
                            : Color(red: 0.90, green: 0.69, blue: 0.72)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            sideDivider

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionAISignal
                    sideDivider
                    sectionOverview
                    sideDivider
                    sectionTrend
                    sideDivider
                    sectionMomentum
                    sideDivider
                    sectionVolatility
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
    }

    private var sideDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.vertical, 12)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .default))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.42))
            .padding(.bottom, 10)
    }

    private func statRow(_ name: String, _ value: String, valueColor: Color) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.60))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(valueColor.opacity(0.92))
        }
        .padding(.bottom, 8)
    }

    private var sectionAISignal: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("AI SIGNAL")
            statRow("Signal", isUptrend ? "UP" : "DOWN", valueColor: isUptrend ? .mint : .red)
            statRow("Confidence", "\(Int(confidence))%", valueColor: .white.opacity(0.88))
            statRow("Stress", "\(Int(100 - confidence))", valueColor: .orange.opacity(0.9))
        }
    }

    private var sectionOverview: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("OVERVIEW")
            statRow("24h Change", "\(percentChange.formatted(.number.precision(.fractionLength(2))))%", valueColor: isUptrend ? .mint : .red)
            statRow("24h High", "$\(Int(high))", valueColor: .mint.opacity(0.9))
            statRow("24h Low", "$\(Int(low))", valueColor: .red.opacity(0.85))
            statRow("24h Volume", volume.formatted(.number.notation(.compactName)), valueColor: .white.opacity(0.9))
        }
    }

    private var sectionTrend: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("TREND")
            statRow("EMA 9", "$\(Int(lastValue - 14))", valueColor: Color(red: 0.56, green: 0.74, blue: 0.96))
            statRow("EMA 21", "$\(Int(lastValue - 36))", valueColor: Color(red: 0.65, green: 0.56, blue: 0.94))
            statRow("Cross", isUptrend ? "Golden ↑" : "Death ↓", valueColor: isUptrend ? .mint : .red)
        }
    }

    private var sectionMomentum: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("MOMENTUM")
            statRow("RSI (14)", "\(52 + Int(absoluteChange * 1.9))", valueColor: .white.opacity(0.9))
            statRow("MACD", absoluteChange.formatted(.number.precision(.fractionLength(2))), valueColor: isUptrend ? .mint : .red)
            statRow("Signal", (absoluteChange * 0.8).formatted(.number.precision(.fractionLength(2))), valueColor: .white.opacity(0.7))
        }
    }

    private var sectionVolatility: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("VOLATILITY")
            statRow(
                "Band Width",
                "\(((high - low) / max(1, lastValue) * 100).formatted(.number.precision(.fractionLength(2))))%",
                valueColor: .blue.opacity(0.9)
            )
            statRow("Data Points", "\(pointsCount)", valueColor: .white.opacity(0.82))
        }
    }
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
            let leadingInset: CGFloat = 12
            let spacing: CGFloat = 8
            let y = container.bounds.height - topInset - buttonSize.height

            close.setFrameOrigin(NSPoint(x: leadingInset, y: y))
            mini.setFrameOrigin(NSPoint(x: leadingInset + buttonSize.width + spacing, y: y))
            zoom.setFrameOrigin(NSPoint(x: leadingInset + (buttonSize.width + spacing) * 2, y: y))
        }
    }
}
