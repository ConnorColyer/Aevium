import SwiftUI
import AppKit
import Charts

private extension Notification.Name {
    static let aeviumExitOldStyleFullscreen = Notification.Name("aeviumExitOldStyleFullscreen")
    static let aeviumCloseWindow = Notification.Name("aeviumCloseWindow")
    static let aeviumMinimizeWindow = Notification.Name("aeviumMinimizeWindow")
}

struct ContentView: View {
    @State private var selectedRange: ChartRange = .week
    @State private var isOldStyleFullscreen = false

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

                AeviumWorkspace(
                    points: visiblePoints,
                    selectedRange: $selectedRange,
                    lastValue: lastValue,
                    absoluteChange: absoluteChange,
                    highValue: highValue,
                    lowValue: lowValue,
                    percentChange: percentChange,
                    pointCount: visiblePoints.count,
                    isOldStyleFullscreen: isOldStyleFullscreen
                )
            }
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.16), value: isOldStyleFullscreen)
            .background(WindowChromeConfigurator(isOldStyleFullscreen: $isOldStyleFullscreen))
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
    let absoluteChange: Double
    let highValue: Double
    let lowValue: Double
    let percentChange: Double
    let pointCount: Int
    let isOldStyleFullscreen: Bool

    private var isUp: Bool { percentChange >= 0 }

    var body: some View {
        HStack(spacing: 0) {
            AeviumRail(isOldStyleFullscreen: isOldStyleFullscreen)

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
                            selectedRange: selectedRange,
                            lastValue: lastValue,
                            absoluteChange: absoluteChange,
                            highValue: highValue,
                            lowValue: lowValue,
                            percentChange: percentChange,
                            pointCount: pointCount,
                            isUp: isUp
                        )
                        .frame(width: 304)
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
    let isOldStyleFullscreen: Bool

    var body: some View {
        VStack(spacing: 22) {
            if isOldStyleFullscreen {
                FullscreenWindowControls()
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer().frame(height: isOldStyleFullscreen ? 56 : 70)

            railButton("chart.xyaxis.line", active: true)
            railButton("tray.full", active: false)
            railButton("waveform.path.ecg", active: false)

            Spacer()

            railButton("slider.horizontal.3", active: false)
        }
        .frame(width: 64)
        .background(Color.black.opacity(0.12))
    }

    private func railButton(_ icon: String, active: Bool) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? Color(red: 0.72, green: 0.88, blue: 0.82) : .white.opacity(0.34))
                .frame(width: 36, height: 36)
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
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
        }
        .padding(.leading, 22)
        .padding(.trailing, 22)
        .frame(height: 40)
    }
}

private struct FullscreenWindowControls: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 7) {
            control(color: Color(red: 1.0, green: 0.37, blue: 0.34), symbol: "xmark", name: "Close") {
                NotificationCenter.default.post(name: .aeviumCloseWindow, object: nil)
            }

            control(color: Color(red: 1.0, green: 0.76, blue: 0.22), symbol: "minus", name: "Minimize") {
                NotificationCenter.default.post(name: .aeviumMinimizeWindow, object: nil)
            }

            control(color: Color(red: 0.20, green: 0.80, blue: 0.34), symbol: "arrow.down.right.and.arrow.up.left", name: "Exit fullscreen") {
                NotificationCenter.default.post(name: .aeviumExitOldStyleFullscreen, object: nil)
            }
        }
        .frame(width: 64, height: 22)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func control(color: Color, symbol: String, name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.22), lineWidth: 0.5)
                    )
                    .shadow(color: color.opacity(0.18), radius: 2, x: 0, y: 1)

                Image(systemName: symbol)
                    .font(.system(size: 6.5, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.black.opacity(0.56))
                    .opacity(isHovering ? 1 : 0)
            }
            .frame(width: 12, height: 12)
            .scaleEffect(isHovering ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .help(name)
    }
}

private struct ChartStage: View {
    let points: [GraphPoint]
    @Binding var selectedRange: ChartRange
    let isUp: Bool

    private static let dayPrefixFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "EEE d"
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
        return (minValue - span * 0.06)...(maxValue + span * 0.07)
    }

    var body: some View {
        GeometryReader { proxy in
            let ticks = adaptiveXAxisTicks(plotWidth: proxy.size.width - 96)
            let labels = makeXAxisLabels(from: ticks)

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
                    .lineStyle(.init(lineWidth: 2.05, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        isUp
                            ? Color(red: 0.60, green: 0.86, blue: 0.75)
                            : Color(red: 0.86, green: 0.68, blue: 0.68)
                    )

                    if let last = points.last {
                        RuleMark(y: .value("Last", last.value))
                            .foregroundStyle(.white.opacity(0.18))
                            .lineStyle(.init(lineWidth: 1.0, dash: [4, 8]))

                        PointMark(
                            x: .value("Time", last.date),
                            y: .value("Price", last.value)
                        )
                        .symbolSize(48)
                        .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .chartLegend(.hidden)
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: .init(lineWidth: 0.55, dash: [2, 8]))
                            .foregroundStyle(.white.opacity(0.13))
                        AxisValueLabel()
                            .foregroundStyle(.white.opacity(0.42))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: ticks) { value in
                        AxisGridLine(stroke: .init(lineWidth: 0.45))
                            .foregroundStyle(.white.opacity(0.07))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(labels[date] ?? Self.timeFormatter.string(from: date))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .offset(y: 5)
                        .foregroundStyle(.white.opacity(0.40))
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    }
                }
                .padding(.top, 34)
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .padding(.bottom, 12)

                AeviumRangeSelector(selectedRange: $selectedRange)
                    .padding(.trailing, 20)
                    .padding(.top, 10)
            }
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

    private func adaptiveXAxisTicks(plotWidth: CGFloat) -> [Date] {
        guard points.count > 2 else { return points.map(\.date) }

        let minimumLabelSpacing: CGFloat = 104
        let desiredTickCount = max(3, Int(plotWidth / minimumLabelSpacing))
        let step = Double(points.count - 1) / Double(max(desiredTickCount - 1, 1))

        var indexSet: Set<Int> = [0, points.count - 1]
        for i in 1..<(desiredTickCount - 1) {
            indexSet.insert(Int((Double(i) * step).rounded()))
        }

        return indexSet
            .sorted()
            .map { points[$0].date }
    }

    private func makeXAxisLabels(from ticks: [Date]) -> [Date: String] {
        guard !ticks.isEmpty else { return [:] }

        let calendar = Calendar.current
        var previousDay: Date?
        var labels: [Date: String] = [:]

        for tick in ticks {
            let day = calendar.startOfDay(for: tick)
            let timeLabel = Self.timeFormatter.string(from: tick)

            if previousDay == nil || day != previousDay {
                let dayLabel = Self.dayPrefixFormatter.string(from: tick)
                labels[tick] = "\(dayLabel)\n\(timeLabel)"
            } else {
                labels[tick] = timeLabel
            }

            previousDay = day
        }

        return labels
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
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(selectedRange == range ? .white.opacity(0.9) : .white.opacity(0.38))
                        .frame(width: 38, height: 27)
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
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct MarketInspector: View {
    @Binding var isOpen: Bool

    let selectedRange: ChartRange
    let lastValue: Double
    let absoluteChange: Double
    let highValue: Double
    let lowValue: Double
    let percentChange: Double
    let pointCount: Int
    let isUp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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

                    Text(signedPercentText)
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

            sectionHeader("INSTRUMENT")
            VStack(spacing: 9) {
                metric("Symbol", "BTC / USDT")
                metric("Venue", "Perp Futures")
                metric("Session", "London")
                metric("Timeframe", selectedRange.rawValue)
                metric("Samples", "\(pointCount)")
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            sectionHeader("PRICE")
            VStack(spacing: 9) {
                metric("Last", number(lastValue))
                metric("Change", signedAbsoluteText)
                metric("Change %", signedPercentText)
                metric("High", number(highValue))
                metric("Low", number(lowValue))
                metric("Range", number(highValue - lowValue))
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("MODEL SIGNALS")

                signalBar("Flow", value: 0.62, color: Color(red: 0.54, green: 0.78, blue: 0.68))
                signalBar("Stress", value: isUp ? 0.28 : 0.58, color: Color(red: 0.78, green: 0.60, blue: 0.48))
                signalBar("Noise", value: 0.36, color: Color(red: 0.56, green: 0.66, blue: 0.78))
                signalBar("Confidence", value: isUp ? 0.66 : 0.42, color: Color(red: 0.68, green: 0.76, blue: 0.94))
            }

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            sectionHeader("RISK & VOLATILITY")
            VStack(spacing: 9) {
                metric("Volatility", "\(volatilityPercent.formatted(.number.precision(.fractionLength(2))))%")
                metric("Bias", isUp ? "Bullish Drift" : "Risk-off")
                metric("Regime", volatilityPercent > 4.5 ? "Elevated" : "Stable")
            }

            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .background(Color.black.opacity(0.10))
    }

    private var signedAbsoluteText: String {
        "\(absoluteChange >= 0 ? "+" : "")\(number(absoluteChange))"
    }

    private var signedPercentText: String {
        "\(percentChange >= 0 ? "+" : "")\(percentChange.formatted(.number.precision(.fractionLength(2))))%"
    }

    private var volatilityPercent: Double {
        guard lastValue != 0 else { return 0 }
        return ((highValue - lowValue) / abs(lastValue)) * 100
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(1.8)
            .foregroundStyle(.white.opacity(0.34))
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

private struct WindowChromeConfigurator: NSViewRepresentable {
    @Binding var isOldStyleFullscreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isOldStyleFullscreen: $isOldStyleFullscreen)
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
            context.coordinator.isOldStyleFullscreenBinding = $isOldStyleFullscreen
            context.coordinator.attach(to: nsView.window)
            context.coordinator.apply()
        }
    }

    final class Coordinator: NSObject {
        var isOldStyleFullscreenBinding: Binding<Bool>

        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var didConfigureWindow = false
        private var previousPresentationOptions: NSApplication.PresentationOptions?
        private var isOldStyleFullscreen = false
        private var restoreFrame: NSRect = .zero
        private var restoreStyleMask: NSWindow.StyleMask = []
        private var restoreLevel: NSWindow.Level = .normal
        private var restoreHasShadow = true
        private var escapeMonitor: Any?

        init(isOldStyleFullscreen: Binding<Bool>) {
            self.isOldStyleFullscreenBinding = isOldStyleFullscreen
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
            }
        }

        func attach(to window: NSWindow?) {
            guard let window else { return }

            let isSameWindow = self.window === window
            self.window = window

            if !isSameWindow {
                didConfigureWindow = false
                for observer in observers {
                    NotificationCenter.default.removeObserver(observer)
                }
                observers.removeAll()

                let names: [Notification.Name] = [
                    NSWindow.didResizeNotification,
                    NSWindow.didBecomeMainNotification,
                    NSWindow.didEndLiveResizeNotification,
                    NSWindow.didEnterFullScreenNotification,
                    NSWindow.didExitFullScreenNotification,
                    .aeviumExitOldStyleFullscreen,
                    .aeviumCloseWindow,
                    .aeviumMinimizeWindow
                ]

                for name in names {
                    let object: Any? = name.rawValue.hasPrefix("aevium") ? nil : window
                    let token = NotificationCenter.default.addObserver(
                        forName: name,
                        object: object,
                        queue: .main
                    ) { [weak self] _ in
                        self?.handleWindowNotification(name)
                    }
                    observers.append(token)
                }
            }

            apply()
        }

        func apply() {
            guard let window else { return }

            if !didConfigureWindow {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.styleMask.insert(.fullSizeContentView)
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.collectionBehavior.remove(.fullScreenAllowsTiling)
                window.collectionBehavior.insert(.fullScreenNone)
                didConfigureWindow = true
            }

            guard
                let close = window.standardWindowButton(.closeButton),
                let mini = window.standardWindowButton(.miniaturizeButton),
                let zoom = window.standardWindowButton(.zoomButton),
                let container = close.superview
            else {
                return
            }

            zoom.target = self
            zoom.action = #selector(toggleOldStyleFullscreen)

            let buttonSize = close.frame.size
            let topInset: CGFloat = 11
            let leadingInset: CGFloat = 6
            let spacing: CGFloat = 8
            let y = container.bounds.height - topInset - buttonSize.height

            close.setFrameOrigin(NSPoint(x: leadingInset, y: y))
            mini.setFrameOrigin(NSPoint(x: leadingInset + buttonSize.width + spacing, y: y))
            zoom.setFrameOrigin(NSPoint(x: leadingInset + (buttonSize.width + spacing) * 2, y: y))
        }

        @objc
        private func toggleOldStyleFullscreen() {
            guard let window else { return }

            if isOldStyleFullscreen {
                exitOldStyleFullscreen(window)
            } else {
                enterOldStyleFullscreen(window)
            }
        }

        private func handleWindowNotification(_ name: Notification.Name) {
            if name == NSWindow.didEnterFullScreenNotification {
                enterFullscreenPresentation()
            } else if name == NSWindow.didExitFullScreenNotification {
                exitFullscreenPresentation()
            } else if name == .aeviumExitOldStyleFullscreen {
                if let window, isOldStyleFullscreen {
                    exitOldStyleFullscreen(window)
                }
                return
            } else if name == .aeviumCloseWindow {
                if let window {
                    closeWindow(window)
                }
                return
            } else if name == .aeviumMinimizeWindow {
                if let window {
                    minimizeWindow(window)
                }
                return
            }

            apply()
        }

        private func enterFullscreenPresentation() {
            if previousPresentationOptions == nil {
                previousPresentationOptions = NSApplication.shared.presentationOptions
            }

            var options = NSApplication.shared.presentationOptions
            options.insert(.autoHideMenuBar)
            options.insert(.autoHideDock)
            NSApplication.shared.presentationOptions = options
        }

        private func exitFullscreenPresentation() {
            if let previousPresentationOptions {
                NSApplication.shared.presentationOptions = previousPresentationOptions
            }
            previousPresentationOptions = nil
        }

        private func enterOldStyleFullscreen(_ window: NSWindow) {
            guard let screen = window.screen ?? NSScreen.main else { return }

            restoreFrame = window.frame
            restoreStyleMask = window.styleMask
            restoreLevel = window.level
            restoreHasShadow = window.hasShadow

            enterFullscreenPresentation()

            window.styleMask = [.borderless]
            window.level = .normal
            window.hasShadow = false
            window.setFrame(screen.frame, display: true, animate: false)
            window.makeKeyAndOrderFront(nil)
            isOldStyleFullscreen = true
            isOldStyleFullscreenBinding.wrappedValue = true

            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                if let window = self?.window, self?.isOldStyleFullscreen == true {
                    self?.exitOldStyleFullscreen(window)
                    return nil
                }
                return event
            }
        }

        private func exitOldStyleFullscreen(_ window: NSWindow) {
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
                self.escapeMonitor = nil
            }

            exitFullscreenPresentation()

            window.styleMask = restoreStyleMask
            window.level = restoreLevel
            window.hasShadow = restoreHasShadow
            window.setFrame(restoreFrame, display: true, animate: false)
            window.makeKeyAndOrderFront(nil)
            isOldStyleFullscreen = false
            isOldStyleFullscreenBinding.wrappedValue = false
            didConfigureWindow = false
            apply()
        }

        private func closeWindow(_ window: NSWindow) {
            if isOldStyleFullscreen {
                exitOldStyleFullscreen(window)
            }
            window.close()
        }

        private func minimizeWindow(_ window: NSWindow) {
            if isOldStyleFullscreen {
                exitOldStyleFullscreen(window)
            }
            window.miniaturize(nil)
        }
    }
}
