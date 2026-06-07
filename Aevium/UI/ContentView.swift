import SwiftUI
import AppKit
import Charts

private extension Notification.Name {
    static let aeviumExitOldStyleFullscreen = Notification.Name("aeviumExitOldStyleFullscreen")
    static let aeviumCloseWindow = Notification.Name("aeviumCloseWindow")
    static let aeviumMinimizeWindow = Notification.Name("aeviumMinimizeWindow")
}

private enum Motion {
    static let standard = Animation.easeOut(duration: 0.16)
    static let micro = Animation.easeOut(duration: 0.08)
    static let chartTransition = Animation.easeOut(duration: 0.18)
    static let spring = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.08)
}

@ViewBuilder
private func liquidGlassSurface<S: Shape>(
    _ shape: S,
    tint: Color = Color.black.opacity(0.22),
    fallbackFill: Color = Color.black.opacity(0.16),
    strokeOpacity: Double = 0.08
) -> some View {
    shape
        .fill(fallbackFill.opacity(0.92))
        .overlay(
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.38),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(shape.stroke(Color.white.opacity(strokeOpacity), lineWidth: 1))
}

private enum WorkspaceTab {
    case market
    case overview
}

private enum InspectorPanel: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case flow = "Orders"
    case risk = "Risk"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summary:
            return "gauge.with.dots.needle.67percent"
        case .flow:
            return "arrow.left.arrow.right"
        case .risk:
            return "shield.lefthalf.filled"
        }
    }
}

private struct BootSplashView: View {
    @State private var isAnimating = false
    @State private var pulsePhase = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.04, blue: 0.06),
                        Color(red: 0.05, green: 0.07, blue: 0.10),
                        Color(red: 0.02, green: 0.03, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.28, green: 0.70, blue: 0.58).opacity(0.10))
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.width * 0.52)
                    .blur(radius: 36)
                    .offset(x: -proxy.size.width * 0.18, y: -proxy.size.height * 0.22)

                Circle()
                    .fill(Color(red: 0.58, green: 0.78, blue: 0.98).opacity(0.08))
                    .frame(width: proxy.size.width * 0.44, height: proxy.size.width * 0.44)
                    .blur(radius: 42)
                    .offset(x: proxy.size.width * 0.24, y: proxy.size.height * 0.18)

                VStack(spacing: 26) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                            .frame(width: 238, height: 238)

                        Circle()
                            .trim(from: 0.06, to: 0.88)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.58, green: 0.92, blue: 0.74),
                                        Color(red: 0.48, green: 0.74, blue: 0.98),
                                        Color(red: 0.90, green: 0.66, blue: 0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 238, height: 238)
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .shadow(color: Color(red: 0.46, green: 0.86, blue: 0.86).opacity(0.36), radius: 18)

                        VStack(spacing: 12) {
                            Text("AEVIUM")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .tracking(11)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color(red: 0.72, green: 0.96, blue: 0.92),
                                            Color(red: 0.63, green: 0.77, blue: 0.99)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                .scaleEffect(pulsePhase ? 1.02 : 0.98)
                                .opacity(pulsePhase ? 1 : 0.86)

                            Text("Booting live market workspace")
                                .font(.system(size: 11.5, weight: .medium))
                                .tracking(2.2)
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }

                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.60, green: 0.92, blue: 0.77),
                                            Color(red: 0.52, green: 0.74, blue: 0.98)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulsePhase ? 1.0 : 0.45)
                                .opacity(pulsePhase ? 1.0 : 0.35)
                                .shadow(color: Color(red: 0.50, green: 0.82, blue: 0.88).opacity(0.45), radius: 8)
                                .animation(
                                    Animation.easeInOut(duration: 0.95)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.18),
                                    value: pulsePhase
                                )
                        }
                    }

                    Text("Loading feeds, cache, and instruments")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.32))
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 32)
                .offset(y: -12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                isAnimating = true
                pulsePhase = true
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var market = AeviumMarketViewModel()
    @State private var selectedRange: ChartRange = .week
    @State private var selectedForesight: ForesightRange = .off
    @State private var selectedIndicators: Set<ForesightIndicator> = []
    @State private var chartSmoothness: Double = 0
    @State private var selectedTab: WorkspaceTab = .overview
    @State private var isOldStyleFullscreen = false
    @State private var bootMinimumElapsed = false
    @State private var bootFallbackElapsed = false
    @State private var bootSplashVisible = true
    @State private var bootTask: Task<Void, Never>?

    private let bootMinimumDuration: UInt64 = 650_000_000
    private let bootFallbackDuration: UInt64 = 2_400_000_000

    private let fallbackPoints = Self.makeSeries()

    private var displayedRange: ChartRange {
        ChartRange(marketTimeRange: market.displayedRange)
    }

    private var visiblePoints: [GraphPoint] {
        let range = displayedRange
        let latestDate = market.points.last?.date ?? Date()
        let cutoff = latestDate.addingTimeInterval(-range.marketTimeRange.duration)
        let source = market.points.filter { $0.date >= cutoff }
        let live = source.enumerated().map { index, point in
            GraphPoint(index: index, date: point.date, value: point.price, volume: point.volume)
        }

        guard live.count > 1 else {
            return market.startupState == .loading ? range.slice(from: fallbackPoints) : []
        }

        return live
    }

    private var indicatorSourcePoints: [GraphPoint] {
        let live = market.points.enumerated().map { index, point in
            GraphPoint(index: index, date: point.date, value: point.price, volume: point.volume)
        }

        guard live.count > 1 else {
            return market.startupState == .loading ? fallbackPoints : []
        }

        return live
    }

    var body: some View {
        let renderedPoints = visiblePoints
        let indicatorPoints = indicatorSourcePoints
        let analytics = renderedPoints.count == market.points.count && market.points.count > 1
            ? market.analytics
            : Self.analytics(from: renderedPoints)
        let isUp = analytics.percentChange >= 0

        GeometryReader { proxy in
            ZStack {
                AmbientBackground(size: proxy.size)

                AeviumWorkspace(
                    market: market,
                    points: renderedPoints,
                    indicatorPoints: indicatorPoints,
                    watchlist: environment.watchlist,
                    selectedTab: $selectedTab,
                    selectedRange: $selectedRange,
                    selectedForesight: $selectedForesight,
                    selectedIndicators: $selectedIndicators,
                    chartSmoothness: $chartSmoothness,
                    displayedRange: displayedRange,
                    instrumentType: market.selectedInstrument.id.type,
                    instrumentSymbol: market.selectedInstrument.compactTitle,
                    instrumentSession: market.selectedInstrument.session,
                    syncState: market.syncState,
                    analytics: analytics,
                    isUp: isUp,
                    isRangeTransitioning: market.isRangeTransitioning,
                    isOldStyleFullscreen: isOldStyleFullscreen
                )

                if bootSplashVisible {
                    BootSplashView()
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .background(WindowChromeConfigurator(isOldStyleFullscreen: $isOldStyleFullscreen))
        }
        .onAppear {
            market.attach(engine: environment.marketDataEngine)
            market.setRange(selectedRange.marketTimeRange)
            beginBootSequence()
        }
        .onChange(of: selectedRange) { _, newValue in
            market.setRange(newValue.marketTimeRange)
        }
        .onChange(of: market.startupState) { _, _ in
            refreshBootSplashVisibility()
        }
        .onReceive(environment.$instrumentSelectionRequest) { request in
            guard let request else { return }
            withAnimation(Motion.spring) {
                selectedTab = .market
            }
            market.selectInstrument(request.instrument)
        }
        .onDisappear {
            bootTask?.cancel()
            bootTask = nil
        }
    }

    private func beginBootSequence() {
        bootTask?.cancel()
        bootMinimumElapsed = false
        bootFallbackElapsed = false
        bootSplashVisible = true

        bootTask = Task {
            try? await Task.sleep(nanoseconds: bootMinimumDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                bootMinimumElapsed = true
                refreshBootSplashVisibility()
            }

            try? await Task.sleep(nanoseconds: bootFallbackDuration - bootMinimumDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                bootFallbackElapsed = true
                refreshBootSplashVisibility()
            }
        }
    }

    private func refreshBootSplashVisibility() {
        guard bootSplashVisible else { return }
        guard bootMinimumElapsed else { return }
        guard bootFallbackElapsed || market.startupState != .loading else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            bootSplashVisible = false
        }
    }

    private static func analytics(from points: [GraphPoint]) -> MarketSeriesAnalytics {
        MarketSeriesCPU.analytics(
            timestamps: points.map { Int64($0.date.timeIntervalSince1970) },
            prices: points.map(\.value)
        )
    }

    private static func makeSeries(count: Int = 720) -> [GraphPoint] {
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
                value: 141.4 + trend + cycle + local + lateRecovery - p * 1.1,
                volume: nil
            )
        }
    }
}

private struct AeviumWorkspace: View {
    @State private var inspectorTargetOpen = true
    @State private var inspectorReveal: CGFloat = 1.0
    @State private var selectedInspectorPanel: InspectorPanel = .summary
    @State private var isSettingsPresented = false

    @ObservedObject var market: AeviumMarketViewModel
    let points: [GraphPoint]
    let indicatorPoints: [GraphPoint]
    @ObservedObject var watchlist: InstrumentWatchlistStore
    @Binding var selectedTab: WorkspaceTab
    @Binding var selectedRange: ChartRange
    @Binding var selectedForesight: ForesightRange
    @Binding var selectedIndicators: Set<ForesightIndicator>
    @Binding var chartSmoothness: Double
    let displayedRange: ChartRange
    let instrumentType: InstrumentType
    let instrumentSymbol: String
    let instrumentSession: String
    let syncState: SyncState
    let analytics: MarketSeriesAnalytics
    let isUp: Bool
    let isRangeTransitioning: Bool
    let isOldStyleFullscreen: Bool

    private let inspectorMaxWidth: CGFloat = 336
    private var inspectorWidth: CGFloat { inspectorMaxWidth * inspectorReveal }
    private var inspectorDividerOpacity: Double { Double(inspectorReveal) }

    var body: some View {
        HStack(spacing: 0) {
            AeviumRail(
                isOldStyleFullscreen: isOldStyleFullscreen,
                selectedTab: selectedTab,
                onSelectMarketTab: showMarket,
                onSelectOverviewTab: {
                    withAnimation(Motion.spring) {
                        selectedTab = .overview
                    }
                },
                onSettingsTapped: { isSettingsPresented = true }
            )

            VStack(spacing: 0) {
                if selectedTab == .market {
                    MarketCommandBar(
                        market: market,
                        watchlist: watchlist,
                        selectedRange: $selectedRange,
                        selectedForesight: $selectedForesight,
                        selectedIndicators: $selectedIndicators,
                        chartSmoothness: $chartSmoothness,
                        syncState: syncState,
                        isInspectorOpen: inspectorTargetOpen,
                        onToggleInspector: toggleInspector
                    )
                    .zIndex(30)
                }

                if selectedTab == .market {
                    Rectangle()
                        .fill(Color.white.opacity(0.065))
                        .frame(height: 1)
                }

                if selectedTab == .market {
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: 0) {
                            SmoothRangeChartStage(
                                points: points,
                                indicatorPoints: indicatorPoints,
                                analytics: analytics,
                                selectedRange: displayedRange,
                                instrumentType: instrumentType,
                                foresightRange: selectedForesight,
                                selectedIndicators: selectedIndicators,
                                chartSmoothness: chartSmoothness,
                                isUp: isUp,
                                drawerReveal: inspectorReveal,
                                isRangeTransitioning: isRangeTransitioning
                            )

                            Rectangle()
                                .fill(Color.white.opacity(0.065))
                                .frame(width: 1)
                                .opacity(inspectorDividerOpacity)

                            ZStack(alignment: .trailing) {
                                MarketInspector(
                                    points: points,
                                    analytics: analytics,
                                    selectedInstrument: market.selectedInstrument,
                                    watchlist: watchlist,
                                    instrumentSymbol: instrumentSymbol,
                                    instrumentSession: instrumentSession,
                                    selectedRange: displayedRange,
                                    isUp: isUp,
                                    selectedPanel: $selectedInspectorPanel,
                                    onSelectWatchlistInstrument: market.selectInstrument
                                )
                                .frame(width: inspectorMaxWidth, alignment: .trailing)
                                .offset(x: (1 - inspectorReveal) * 14)
                                .opacity(0.42 + (0.58 * inspectorReveal))
                            }
                            .frame(width: inspectorWidth, alignment: .trailing)
                            .clipped()
                            .allowsHitTesting(inspectorReveal > 0.01)
	                        }

                        if points.isEmpty {
                            MarketSeriesLoadingOverlay(
                                symbol: instrumentSymbol,
                                state: syncState
                            )
                            .padding(.trailing, inspectorWidth)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }
                    }
                } else {
                    MarketOverviewTab()
                }
            }
        }
        .background(
            Color(red: 0.105, green: 0.117, blue: 0.130).opacity(0.64)
        )
        .sheet(isPresented: $isSettingsPresented) {
            AeviumSettingsView()
        }
    }

    private func toggleInspector() {
        inspectorTargetOpen.toggle()
        withAnimation(Motion.spring) {
            inspectorReveal = inspectorTargetOpen ? 1.0 : 0.0
        }
    }

    private func showMarket() {
        withAnimation(Motion.spring) {
            selectedTab = .market
        }
    }
}

private struct AeviumRail: View {
    let isOldStyleFullscreen: Bool
    let selectedTab: WorkspaceTab
    let onSelectMarketTab: () -> Void
    let onSelectOverviewTab: () -> Void
    let onSettingsTapped: () -> Void
    @Namespace private var railSelectionNamespace

    var body: some View {
        VStack(spacing: 14) {
            if isOldStyleFullscreen {
                FullscreenWindowControls()
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer().frame(height: isOldStyleFullscreen ? 48 : 56)

            railButton("square.grid.2x2", label: "Home", active: selectedTab == .overview, help: "Home", action: onSelectOverviewTab)
            railButton("chart.xyaxis.line", label: "Market", active: selectedTab == .market, help: "Market view", action: onSelectMarketTab)

            Spacer()

            railButton("slider.horizontal.3", label: "Settings", active: false, help: "Settings", action: onSettingsTapped)
        }
        .frame(width: 74)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.10)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func railButton(_ icon: String, label: String, active: Bool, help: String? = nil, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))

                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(active ? Color(red: 0.72, green: 0.88, blue: 0.82) : .white.opacity(0.36))
            .frame(width: 54, height: 48)
            .background {
                if active {
                    liquidGlassSurface(
                        RoundedRectangle(cornerRadius: 8, style: .continuous),
                        fallbackFill: Color.white.opacity(0.085)
                    )
                        .matchedGeometryEffect(id: "rail-selection", in: railSelectionNamespace)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color(red: 0.72, green: 0.88, blue: 0.82))
                                .frame(width: 3, height: 22)
                                .offset(x: -7)
                        }
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(help ?? icon)
        .animation(Motion.spring, value: active)
    }
}

private struct WorkspaceTopBar: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AEVIUM")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.38))

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Text(subtitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)

            Spacer()
        }
        .padding(.leading, 22)
        .padding(.trailing, 22)
        .frame(height: 58)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.04, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
            }
        )
    }
}

private struct MarketCommandBar: View {
    @ObservedObject var market: AeviumMarketViewModel
    @ObservedObject var watchlist: InstrumentWatchlistStore
    @Binding var selectedRange: ChartRange
    @Binding var selectedForesight: ForesightRange
    @Binding var selectedIndicators: Set<ForesightIndicator>
    @Binding var chartSmoothness: Double
    let syncState: SyncState
    let isInspectorOpen: Bool
    let onToggleInspector: () -> Void

    private var isSaved: Bool {
        watchlist.contains(market.selectedInstrument)
    }

    var body: some View {
        HStack(spacing: 8) {
            brandBlock

            Divider()
                .overlay(Color.white.opacity(0.08))
                .frame(height: 32)

            InstrumentSearchControl(market: market, width: 260)
                .layoutPriority(1)

            Button {
                withAnimation(Motion.spring) {
                    watchlist.toggle(market.selectedInstrument)
                }
            } label: {
                Image(systemName: isSaved ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSaved ? Color(red: 0.92, green: 0.78, blue: 0.44) : .white.opacity(0.58))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        isSaved ? Color(red: 0.18, green: 0.15, blue: 0.10).opacity(0.98) : Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98),
                                        isSaved ? Color(red: 0.11, green: 0.10, blue: 0.08).opacity(0.98) : Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(isSaved ? 0.08 : 0.05), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help(isSaved ? "Remove from watchlist" : "Add to watchlist")

            AeviumRangeSelector(selectedRange: $selectedRange)
            ForesightSelector(selectedForesight: $selectedForesight)
            IndicatorMenuButton(selectedIndicators: $selectedIndicators)
            ChartResolutionControl(chartSmoothness: $chartSmoothness)

            Spacer(minLength: 8)

            SyncStatusStrip(state: syncState)

            Button(action: onToggleInspector) {
                Image(systemName: isInspectorOpen ? "sidebar.right" : "sidebar.leading")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98),
                                        Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(isInspectorOpen ? 0.08 : 0.05), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help(isInspectorOpen ? "Hide inspector" : "Show inspector")
        }
        .padding(.leading, 18)
        .padding(.trailing, 18)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98),
                            Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        )
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("AEVIUM")
                .font(.system(size: 10, weight: .semibold, design: .default))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.38))

            Text(market.selectedInstrument.compactTitle.uppercased())
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(width: 128, alignment: .leading)
    }
}

struct AeviumSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var finnhubAPIKey = ""
    @State private var isKeyVisible = false
    @State private var statusMessage = "Stock data uses Finnhub. Crypto data uses Binance public endpoints and needs no key."
    @State private var statusIsError = false

    private var hasSavedKey: Bool {
        AeviumAPIKeyStore.hasFinnhubAPIKey()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aevium Settings")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))

                    Text("Provider keys stay in your macOS Keychain, not in the project folder or Git history.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    providerBadge(title: "Binance", subtitle: "Crypto", state: "Public")
                    providerBadge(title: "Finnhub", subtitle: "Equities", state: hasSavedKey ? "Key saved" : "Needs key")
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Finnhub API Key")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.48))

                    HStack(spacing: 8) {
                        Group {
                            if isKeyVisible {
                                TextField("Paste free Finnhub key", text: $finnhubAPIKey)
                            } else {
                                SecureField("Paste free Finnhub key", text: $finnhubAPIKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                                )
                        )

                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help(isKeyVisible ? "Hide key" : "Show key")
                    }

                    Text(statusMessage)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(statusIsError ? Color(red: 1.0, green: 0.42, blue: 0.42) : .white.opacity(0.46))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        saveKey()
                    } label: {
                        Text("Save Locally")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.78))
                            .frame(height: 34)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.72, green: 0.88, blue: 0.82),
                                                Color(red: 0.58, green: 0.78, blue: 0.72)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        clearKey()
                    } label: {
                        Text("Clear Key")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .frame(height: 34)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.11, blue: 0.12).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.035),
                                Color(red: 0.08, green: 0.12, blue: 0.13).opacity(0.38),
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    )
            )
        }
        .padding(22)
        .frame(width: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.13),
                    Color(red: 0.07, green: 0.08, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            finnhubAPIKey = AeviumAPIKeyStore.finnhubAPIKey() ?? ""
        }
    }

    private func providerBadge(title: String, subtitle: String, state: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))

            HStack(spacing: 6) {
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.42))
                Circle()
                    .fill(state == "Needs key" ? Color(red: 0.90, green: 0.62, blue: 0.34) : Color(red: 0.48, green: 0.82, blue: 0.66))
                    .frame(width: 5, height: 5)
                Text(state)
                    .foregroundStyle(.white.opacity(0.54))
            }
            .font(.system(size: 11.5, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }

    private func saveKey() {
        do {
            try AeviumAPIKeyStore.setFinnhubAPIKey(finnhubAPIKey)
            statusIsError = false
            statusMessage = finnhubAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Finnhub key removed. Crypto data will continue to work through Binance."
                : "Saved to macOS Keychain. Equity searches and live stock data will use this key."
        } catch {
            statusIsError = true
            statusMessage = "Could not save key: \(error.localizedDescription)"
        }
    }

    private func clearKey() {
        finnhubAPIKey = ""
        saveKey()
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
        .animation(Motion.micro, value: isHovering)
        .buttonStyle(.plain)
        .help(name)
    }
}

private struct SmoothRangeChartStage: View {
    let points: [GraphPoint]
    let indicatorPoints: [GraphPoint]
    let analytics: MarketSeriesAnalytics
    let selectedRange: ChartRange
    let instrumentType: InstrumentType
    let foresightRange: ForesightRange
    let selectedIndicators: Set<ForesightIndicator>
    let chartSmoothness: Double
    let isUp: Bool
    let drawerReveal: CGFloat
    let isRangeTransitioning: Bool

    @State private var lastSnapshot: ChartSnapshot?
    @State private var outgoingSnapshot: ChartSnapshot?
    @State private var incomingOpacity = 1.0
    @State private var outgoingOpacity = 0.0
    @State private var transitionTask: Task<Void, Never>?

    private struct ChartSnapshot {
        struct Key: Equatable {
            let range: ChartRange
            let instrumentType: InstrumentType
            let count: Int
            let firstID: TimeInterval?
            let lastID: TimeInterval?
            let indicatorCount: Int
            let indicatorFirstID: TimeInterval?
            let indicatorLastID: TimeInterval?
            let lowValue: Double
            let highValue: Double
            let lastValue: Double
            let foresightRange: ForesightRange
            let selectedIndicators: Set<ForesightIndicator>
            let chartSmoothness: Double
            let isUp: Bool
            let drawerReveal: CGFloat
        }

        let points: [GraphPoint]
        let indicatorPoints: [GraphPoint]
        let analytics: MarketSeriesAnalytics
        let range: ChartRange
        let instrumentType: InstrumentType
        let foresightRange: ForesightRange
        let selectedIndicators: Set<ForesightIndicator>
        let chartSmoothness: Double
        let isUp: Bool
        let drawerReveal: CGFloat

        var key: Key {
            Key(
                range: range,
                instrumentType: instrumentType,
                count: points.count,
                firstID: points.first?.id,
                lastID: points.last?.id,
                indicatorCount: indicatorPoints.count,
                indicatorFirstID: indicatorPoints.first?.id,
                indicatorLastID: indicatorPoints.last?.id,
                lowValue: analytics.lowValue,
                highValue: analytics.highValue,
                lastValue: analytics.lastValue,
                foresightRange: foresightRange,
                selectedIndicators: selectedIndicators,
                chartSmoothness: chartSmoothness,
                isUp: isUp,
                drawerReveal: drawerReveal
            )
        }
    }

    private var currentSnapshot: ChartSnapshot {
        ChartSnapshot(
            points: points,
            indicatorPoints: indicatorPoints,
            analytics: analytics,
            range: selectedRange,
            instrumentType: instrumentType,
            foresightRange: foresightRange,
            selectedIndicators: selectedIndicators,
            chartSmoothness: chartSmoothness,
            isUp: isUp,
            drawerReveal: drawerReveal
        )
    }

    var body: some View {
        let snapshot = currentSnapshot
        let handoffSnapshot = activeOutgoingSnapshot(for: snapshot)
        let handoffIsStarting = outgoingSnapshot == nil && handoffSnapshot != nil

        ZStack {
            chart(for: snapshot)
                .id(snapshot.range.id)
                .opacity(handoffSnapshot == nil ? pendingOpacity : (handoffIsStarting ? 0.0 : incomingOpacity))
                .zIndex(0)

            if let handoffSnapshot {
                chart(for: handoffSnapshot)
                    .id("outgoing-\(handoffSnapshot.range.id)")
                    .opacity(handoffIsStarting ? 1.0 : outgoingOpacity)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }
        }
        .compositingGroup()
        .onAppear {
            lastSnapshot = snapshot
        }
        .onChange(of: snapshot.key) { _, _ in
            reconcileTransition(to: snapshot)
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
    }

    private var pendingOpacity: Double {
        isRangeTransitioning ? 0.88 : 1.0
    }

    private func activeOutgoingSnapshot(for snapshot: ChartSnapshot) -> ChartSnapshot? {
        if let outgoingSnapshot {
            return outgoingSnapshot
        }

        guard let lastSnapshot, lastSnapshot.range != snapshot.range else {
            return nil
        }

        return lastSnapshot
    }

    private func chart(for snapshot: ChartSnapshot) -> some View {
        ChartStage(
            points: snapshot.points,
            indicatorPoints: snapshot.indicatorPoints,
            analytics: snapshot.analytics,
            selectedRange: snapshot.range,
            instrumentType: snapshot.instrumentType,
            foresightRange: snapshot.foresightRange,
            selectedIndicators: snapshot.selectedIndicators,
            chartSmoothness: snapshot.chartSmoothness,
            isUp: snapshot.isUp,
            drawerReveal: snapshot.drawerReveal
        )
    }

    private func reconcileTransition(to snapshot: ChartSnapshot) {
        guard let previous = lastSnapshot else {
            lastSnapshot = snapshot
            return
        }

        guard previous.range != snapshot.range else {
            lastSnapshot = snapshot
            return
        }

        startRangeTransition(from: previous, to: snapshot)
    }

    private func startRangeTransition(from previous: ChartSnapshot, to snapshot: ChartSnapshot) {
        transitionTask?.cancel()

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            outgoingSnapshot = previous
            outgoingOpacity = 1.0
            incomingOpacity = 0.0
            lastSnapshot = snapshot
        }

        transitionTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }

            withAnimation(Motion.chartTransition) {
                incomingOpacity = 1.0
                outgoingOpacity = 0.0
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            var cleanupTransaction = Transaction()
            cleanupTransaction.animation = nil
            withTransaction(cleanupTransaction) {
                outgoingSnapshot = nil
                outgoingOpacity = 0.0
                incomingOpacity = 1.0
            }
        }
    }
}

private struct ChartStage: View {
    let points: [GraphPoint]
    let indicatorPoints: [GraphPoint]
    let analytics: MarketSeriesAnalytics
    let selectedRange: ChartRange
    let instrumentType: InstrumentType
    let foresightRange: ForesightRange
    let selectedIndicators: Set<ForesightIndicator>
    let chartSmoothness: Double
    let isUp: Bool
    let drawerReveal: CGFloat
    @State private var displayedXDomain: ClosedRange<Date>?
    @State private var displayedYAxis: YAxisConfiguration?
    @State private var lastCameraRange: ChartRange?
    @State private var hoverLocation: CGPoint?

    private struct YAxisConfiguration: Equatable {
        let domain: ClosedRange<Double>
        let ticks: [Double]
        let step: Double
    }

    private struct CameraInput: Equatable {
        let range: ChartRange
        let instrumentType: InstrumentType
        let count: Int
        let firstID: TimeInterval?
        let lastID: TimeInterval?
        let lowValue: Double
        let highValue: Double
        let lastValue: Double
        let foresightRange: ForesightRange
        let selectedIndicators: Set<ForesightIndicator>
        let chartSmoothness: Double
    }

    private struct IndicatorPoint {
        let date: Date
        let value: Double
    }

    private struct IndicatorOverlay {
        let id: String
        let label: String
        let color: Color
        let lineWidth: CGFloat
        let dashed: Bool
        let points: [IndicatorPoint]
    }

    private struct HoverIndicatorValue: Identifiable {
        let id: String
        let label: String
        let formattedValue: String
        let color: Color
    }

    private struct XAxisProjection {
        struct Interval {
            let actualStart: Date
            let actualEnd: Date
            let projectedStart: TimeInterval
            let projectedEnd: TimeInterval
        }

        let intervals: [Interval]
        let totalDuration: TimeInterval

        func progress(for date: Date) -> Double {
            guard !intervals.isEmpty, totalDuration > 0 else { return 0 }

            if date <= intervals[0].actualStart {
                return 0
            }

            for interval in intervals {
                if date <= interval.actualEnd {
                    let offset = interval.projectedStart + max(date.timeIntervalSince(interval.actualStart), 0)
                    return (offset / totalDuration).clamped(to: 0...1)
                }
            }

            return 1
        }

        func date(at progress: Double) -> Date {
            guard let first = intervals.first else { return Date() }
            let offset = totalDuration * progress.clamped(to: 0...1)

            for interval in intervals {
                if offset <= interval.projectedEnd {
                    return interval.actualStart.addingTimeInterval(max(offset - interval.projectedStart, 0))
                }
            }

            return intervals.last?.actualEnd ?? first.actualStart
        }

        func tickDates(targetCount: Int) -> [Date] {
            guard targetCount > 1, totalDuration > 0 else {
                return intervals.first.map { [$0.actualStart, $0.actualEnd] } ?? []
            }

            var dates: [Date] = []
            dates.reserveCapacity(targetCount)

            for index in 0..<targetCount {
                let progress = Double(index) / Double(max(targetCount - 1, 1))
                let date = date(at: progress)
                if let last = dates.last, abs(date.timeIntervalSince(last)) < 60 {
                    continue
                }
                dates.append(date)
            }

            return dates
        }
    }

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

    private static let hoverFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "EEE d, HH:mm"
        return formatter
    }()

    private var yAxisConfiguration: YAxisConfiguration {
        let renderPoints = chartRenderablePoints()
        let indicatorSourcePoints = indicatorRenderablePoints()
        let domain = targetXDomain() ?? fallbackXDomain()
        let indicatorOverlays = makeIndicatorOverlays(
            from: indicatorSourcePoints.isEmpty ? renderPoints : indicatorSourcePoints,
            visibleDomain: domain,
            futureUpperBound: domain.upperBound
        )

        return makeYAxisConfiguration(including: indicatorOverlays)
    }

    private var cameraInput: CameraInput {
        CameraInput(
            range: selectedRange,
            instrumentType: instrumentType,
            count: points.count,
            firstID: points.first?.id,
            lastID: points.last?.id,
            lowValue: analytics.lowValue,
            highValue: analytics.highValue,
            lastValue: analytics.lastValue,
            foresightRange: foresightRange,
            selectedIndicators: selectedIndicators,
            chartSmoothness: chartSmoothness
        )
    }

    private func makeYAxisConfiguration(lowValue: Double, highValue: Double) -> YAxisConfiguration {
        let safeLow = lowValue.isFinite && lowValue > 0 ? lowValue : 0
        let safeHigh = highValue.isFinite && highValue > 0 ? highValue : safeLow + 1
        let minValue = safeLow
        let maxValue = safeHigh == safeLow ? safeLow + 1 : safeHigh
        let span = max(maxValue - minValue, max(abs(maxValue), 1) * 0.001)
        let rawStep = span / 5
        let step = niceStep(for: rawStep)

        let paddedMin = floor((minValue - step * 0.30) / step) * step
        let paddedMax = ceil((maxValue + step * 0.40) / step) * step

        let startIndex = Int(floor(paddedMin / step))
        let endIndex = Int(ceil(paddedMax / step))
        let ticks = (startIndex...endIndex).map { Double($0) * step }

        return YAxisConfiguration(
            domain: paddedMin...paddedMax,
            ticks: ticks,
            step: step
        )
    }

    private func makeYAxisConfiguration(including indicatorOverlays: [IndicatorOverlay]) -> YAxisConfiguration {
        var lowValue = analytics.lowValue
        var highValue = analytics.highValue

        for overlay in indicatorOverlays {
            for point in overlay.points where point.value.isFinite && point.value > 0 {
                lowValue = min(lowValue, point.value)
                highValue = max(highValue, point.value)
            }
        }

        return makeYAxisConfiguration(lowValue: lowValue, highValue: highValue)
    }

    var body: some View {
        GeometryReader { proxy in
            let xDomain = displayedXDomain ?? targetXDomain() ?? fallbackXDomain()
            let renderPoints = chartRenderablePoints()
            let indicatorSourcePoints = indicatorRenderablePoints()
            let renderSegments = segmentedRenderablePoints(from: renderPoints)
            let visualSegments = renderSegments.map { smoothedRenderablePoints(from: $0) }
            let xProjection = makeXAxisProjection(
                domain: xDomain,
                pointSegments: renderSegments
            )
            let ticks = adaptiveXAxisTicks(
                plotWidth: proxy.size.width,
                domain: xDomain,
                projection: xProjection
            )
            let labels = makeXAxisLabels(from: ticks)
            let indicatorOverlays = makeIndicatorOverlays(
                from: indicatorSourcePoints.isEmpty ? renderPoints : indicatorSourcePoints,
                visibleDomain: xDomain,
                futureUpperBound: xDomain.upperBound
            )
            let yAxis = displayedYAxis ?? makeYAxisConfiguration(including: indicatorOverlays)
            let plot = plotRect(in: proxy.size)
            let hoverPoint = nearestPoint(
                to: hoverLocation,
                in: plot,
                points: renderPoints,
                xDomain: xDomain,
                projection: xProjection
            )

            ZStack(alignment: .topLeading) {
                futureLaneOverlay(
                    plot: plot,
                    xDomain: xDomain,
                    projection: xProjection
                )

                Canvas { context, size in
                    drawChart(
                        context: &context,
                        size: size,
                        points: renderPoints,
                        pointSegments: renderSegments,
                        visualPointSegments: visualSegments,
                        indicatorOverlays: indicatorOverlays,
                        xDomain: xDomain,
                        xProjection: xProjection,
                        yAxis: yAxis,
                        xTicks: ticks
                    )
                }

                axisLabelOverlay(
                    size: proxy.size,
                    xDomain: xDomain,
                    xProjection: xProjection,
                    yAxis: yAxis,
                    xTicks: ticks,
                    labels: labels
                )

                if let hoverPoint {
                    hoverOverlay(
                        point: hoverPoint,
                        indicatorOverlays: indicatorOverlays,
                        plot: plot,
                        xDomain: xDomain,
                        xProjection: xProjection,
                        yAxis: yAxis
                    )
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverLocation = location
                case .ended:
                    hoverLocation = nil
                }
            }
            .scaleEffect(x: 1.0 - (0.010 * drawerReveal), y: 1, anchor: .leading)
            .offset(x: -3.0 * drawerReveal)
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.12 * drawerReveal)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 24)
                .allowsHitTesting(false)
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
        .onAppear {
            refreshChartCamera(animated: false)
        }
        .onChange(of: cameraInput) { _, _ in
            refreshChartCamera(animated: true)
        }
    }

    private func plotRect(in size: CGSize) -> CGRect {
        let leading: CGFloat = 66
        let trailing: CGFloat = 24 + (drawerReveal * 8)
        let top: CGFloat = 50
        let bottom: CGFloat = 46

        return CGRect(
            x: leading,
            y: top,
            width: max(size.width - leading - trailing, 1),
            height: max(size.height - top - bottom, 1)
        )
    }

    private func drawChart(
        context: inout GraphicsContext,
        size: CGSize,
        points: [GraphPoint],
        pointSegments: [[GraphPoint]],
        visualPointSegments: [[GraphPoint]],
        indicatorOverlays: [IndicatorOverlay],
        xDomain: ClosedRange<Date>,
        xProjection: XAxisProjection?,
        yAxis: YAxisConfiguration,
        xTicks: [Date]
    ) {
        let plot = plotRect(in: size)

        for tick in yAxis.ticks {
            let y = yPosition(for: tick, in: plot, yDomain: yAxis.domain)
            var path = Path()
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(
                path,
                with: .color(.white.opacity(0.12)),
                style: StrokeStyle(lineWidth: 0.55, dash: [2, 8])
            )
        }

        for tick in xTicks {
            let x = xPosition(for: tick, in: plot, xDomain: xDomain, projection: xProjection)
            var path = Path()
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(path, with: .color(.white.opacity(0.065)), lineWidth: 0.5)
        }

        var border = Path()
        border.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        border.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.stroke(border, with: .color(.white.opacity(0.12)), lineWidth: 0.8)

        guard points.count > 1 else { return }

        let lineColor = isUp
            ? Color(red: 0.60, green: 0.86, blue: 0.75)
            : Color(red: 0.88, green: 0.68, blue: 0.68)

        let areaFill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                lineColor.opacity(0.22),
                Color(red: 0.20, green: 0.28, blue: 0.30).opacity(0.04)
            ]),
            startPoint: CGPoint(x: plot.midX, y: plot.minY),
            endPoint: CGPoint(x: plot.midX, y: plot.maxY)
        )

        let shouldBridgeCompressedSessions = instrumentType == .equity && xProjection != nil
        let drawSegments = shouldBridgeCompressedSessions
            ? [visualPointSegments.flatMap { $0 }]
            : visualPointSegments

        for segment in drawSegments where segment.count > 1 {
            let mapped = segment.map {
                position(for: $0, in: plot, xDomain: xDomain, projection: xProjection, yDomain: yAxis.domain)
            }

            guard let first = mapped.first, let last = mapped.last else { continue }

            var area = Path()
            area.move(to: CGPoint(x: first.x, y: plot.maxY))
            for point in mapped {
                area.addLine(to: point)
            }
            area.addLine(to: CGPoint(x: last.x, y: plot.maxY))
            area.closeSubpath()
            context.fill(area, with: areaFill)
        }

        drawIndicatorOverlays(
            context: &context,
            overlays: indicatorOverlays,
            plot: plot,
            xDomain: xDomain,
            xProjection: xProjection,
            yDomain: yAxis.domain
        )

        for segment in drawSegments where segment.count > 1 {
            let mapped = segment.map {
                position(for: $0, in: plot, xDomain: xDomain, projection: xProjection, yDomain: yAxis.domain)
            }

            guard let first = mapped.first else { continue }

            var line = Path()
            line.move(to: first)
            for point in mapped.dropFirst() {
                line.addLine(to: point)
            }

            context.stroke(
                line,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
            )
        }

        drawSessionGapMarkers(
            context: &context,
            pointSegments: pointSegments,
            plot: plot,
            xDomain: xDomain,
            projection: xProjection
        )

        if let latest = points.last {
            let latestPoint = position(for: latest, in: plot, xDomain: xDomain, projection: xProjection, yDomain: yAxis.domain)
            var rule = Path()
            rule.move(to: CGPoint(x: plot.minX, y: latestPoint.y))
            rule.addLine(to: CGPoint(x: plot.maxX, y: latestPoint.y))
            context.stroke(
                rule,
                with: .color(.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1, dash: [5, 8])
            )

            let markerRect = CGRect(x: latestPoint.x - 4, y: latestPoint.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: markerRect), with: .color(.white.opacity(0.96)))
            context.stroke(Path(ellipseIn: markerRect.insetBy(dx: -1.5, dy: -1.5)), with: .color(lineColor.opacity(0.65)), lineWidth: 1)
        }
    }

    private func smoothedRenderablePoints(from points: [GraphPoint]) -> [GraphPoint] {
        guard points.count > 4, chartSmoothness > 0.001 else { return points }

        let count = points.count
        let radius = max(1, Int(round(2 + (chartSmoothness * 12))))
        let sigma = max(1.0, Double(radius) * (0.55 + (chartSmoothness * 0.15)))
        let passes = max(1, Int(round(1 + (chartSmoothness * 3))))
        let offsets = Array(-radius...radius)
        let kernel: [Double] = offsets.map { offset in
            exp(-0.5 * pow(Double(offset) / sigma, 2))
        }

        var smoothedValues = points.map(\.value)

        for _ in 0..<passes {
            var nextValues = smoothedValues

            for index in 1..<(count - 1) {
                var weightedSum = 0.0
                var totalWeight = 0.0

                for (kernelIndex, offset) in offsets.enumerated() {
                    let sampleIndex = min(max(index + offset, 0), count - 1)
                    let weight = kernel[kernelIndex]
                    weightedSum += smoothedValues[sampleIndex] * weight
                    totalWeight += weight
                }

                nextValues[index] = weightedSum / max(totalWeight, 0.0001)
            }

            smoothedValues = nextValues
        }

        return points.enumerated().map { index, point in
            guard index > 0, index < count - 1 else { return point }

            let blendedValue = point.value + ((smoothedValues[index] - point.value) * chartSmoothness)
            return GraphPoint(
                index: point.index,
                date: point.date,
                value: blendedValue,
                volume: point.volume
            )
        }
    }

    private func drawIndicatorOverlays(
        context: inout GraphicsContext,
        overlays: [IndicatorOverlay],
        plot: CGRect,
        xDomain: ClosedRange<Date>,
        xProjection: XAxisProjection?,
        yDomain: ClosedRange<Double>
    ) {
        for overlay in overlays {
            guard overlay.points.count > 1 else { continue }

            let pointSegments = overlay.dashed
                ? [overlay.points]
                : segmentedIndicatorPoints(from: overlay.points)
            let drawSegments = instrumentType == .equity && xProjection != nil
                ? [pointSegments.flatMap { $0 }]
                : pointSegments

            for segment in drawSegments where segment.count > 1 {
                var path = Path()
                let mapped = segment.map {
                    position(
                        for: GraphPoint(index: 0, date: $0.date, value: $0.value, volume: nil),
                        in: plot,
                        xDomain: xDomain,
                        projection: xProjection,
                        yDomain: yDomain
                    )
                }

                guard let first = mapped.first else { continue }
                path.move(to: first)
                for point in mapped.dropFirst() {
                    path.addLine(to: point)
                }

                context.stroke(
                    path,
                    with: .color(overlay.color),
                    style: StrokeStyle(
                        lineWidth: overlay.lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: overlay.dashed ? [6, 5] : []
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func futureLaneOverlay(
        plot: CGRect,
        xDomain: ClosedRange<Date>,
        projection: XAxisProjection?
    ) -> some View {
        if foresightRange != .off, let latestDate = points.last?.date {
            let latestX = xPosition(for: latestDate, in: plot, xDomain: xDomain, projection: projection)
            let laneWidth = max(plot.maxX - latestX, 0)

            if laneWidth > 0.5 {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.34, blue: 0.40).opacity(0.13),
                                    Color(red: 0.16, green: 0.21, blue: 0.25).opacity(0.19)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Rectangle()
                        .fill(Color.white.opacity(0.11))
                        .frame(width: 1)
                }
                .frame(width: laneWidth, height: plot.height)
                .position(
                    x: latestX + laneWidth / 2,
                    y: plot.midY
                )
                .allowsHitTesting(false)
            }
        }
    }

    private func makeIndicatorOverlays(
        from points: [GraphPoint],
        visibleDomain: ClosedRange<Date>,
        futureUpperBound: Date
    ) -> [IndicatorOverlay] {
        guard points.count > 2, !selectedIndicators.isEmpty else { return [] }

        var overlays: [IndicatorOverlay] = []
        let latestActualDate = points.last?.date
        func append(_ series: [IndicatorPoint], as indicator: ForesightIndicator) {
            overlays.append(
                contentsOf: overlaysForSeries(
                    series,
                    indicator: indicator,
                    visibleDomain: visibleDomain,
                    futureUpperBound: futureUpperBound
                )
            )
        }
        func appendFuture(_ series: [IndicatorPoint], as indicator: ForesightIndicator) {
            overlays.append(
                contentsOf: futureOverlaysForSeries(
                    series,
                    indicator: indicator,
                    latestActualDate: latestActualDate,
                    futureUpperBound: futureUpperBound
                )
            )
        }

        for indicator in ForesightIndicator.menuCases where selectedIndicators.contains(indicator) {
            switch indicator {
            case .sma10:
                append(smaSeries(period: 10, points: points), as: indicator)
            case .sma20:
                append(smaSeries(period: 20, points: points), as: indicator)
            case .sma50:
                append(smaSeries(period: 50, points: points), as: indicator)
            case .sma100:
                append(smaSeries(period: 100, points: points), as: indicator)
            case .sma200:
                append(smaSeries(period: 200, points: points), as: indicator)
            case .ema9:
                append(emaSeries(period: 9, points: points), as: indicator)
            case .ema12:
                append(emaSeries(period: 12, points: points), as: indicator)
            case .ema20:
                append(emaSeries(period: 20, points: points), as: indicator)
            case .ema26:
                append(emaSeries(period: 26, points: points), as: indicator)
            case .ema50:
                append(emaSeries(period: 50, points: points), as: indicator)
            case .ema100:
                append(emaSeries(period: 100, points: points), as: indicator)
            case .ema200:
                append(emaSeries(period: 200, points: points), as: indicator)
            case .wma20:
                append(wmaSeries(period: 20, points: points), as: indicator)
            case .hma21:
                append(hmaSeries(period: 21, points: points), as: indicator)
            case .vwap:
                append(vwapSeries(points: points), as: indicator)
            case .previousClose:
                append(previousCloseSeries(points: points, visibleDomain: visibleDomain, futureUpperBound: futureUpperBound), as: indicator)
            case .bollingerBands:
                let bands = bollingerBands(period: 20, points: points)
                append(bands.mid, as: .bollingerMid)
                append(bands.upper, as: .bollingerUpper)
                append(bands.lower, as: .bollingerLower)
            case .bollingerBands50:
                let bands = bollingerBands(period: 50, points: points)
                append(bands.mid, as: .bollinger50Mid)
                append(bands.upper, as: .bollinger50Upper)
                append(bands.lower, as: .bollinger50Lower)
            case .donchianChannel:
                let channel = donchianChannel(period: 20, points: points)
                append(channel.upper, as: .donchianUpper)
                append(channel.lower, as: .donchianLower)
            case .donchian55:
                let channel = donchianChannel(period: 55, points: points)
                append(channel.upper, as: .donchian55Upper)
                append(channel.lower, as: .donchian55Lower)
            case .keltnerChannel:
                let channel = keltnerChannel(period: 20, multiplier: 1.5, points: points)
                append(channel.mid, as: .keltnerMid)
                append(channel.upper, as: .keltnerUpper)
                append(channel.lower, as: .keltnerLower)
            case .atrBands:
                let bands = atrBands(period: 14, multiplier: 2.0, points: points)
                append(bands.upper, as: .atrUpper)
                append(bands.lower, as: .atrLower)
            case .regressionChannel:
                let channel = regressionChannel(period: min(max(points.count / 2, 20), 120), points: points)
                append(channel.mid, as: .regressionMid)
                append(channel.upper, as: .regressionUpper)
                append(channel.lower, as: .regressionLower)
            case .trendDrift:
                appendFuture(trendDriftProjection(points: points, futureUpperBound: futureUpperBound), as: indicator)
            case .meanReversion:
                appendFuture(meanReversionProjection(points: points, futureUpperBound: futureUpperBound), as: indicator)
            case .vwapCarry:
                appendFuture(vwapCarryProjection(points: points, futureUpperBound: futureUpperBound), as: indicator)
            case .volatilityCone:
                let cone = volatilityConeProjection(points: points, futureUpperBound: futureUpperBound)
                appendFuture(cone.mid, as: .volatilityConeMid)
                appendFuture(cone.upper, as: .volatilityConeUpper)
                appendFuture(cone.lower, as: .volatilityConeLower)
            case .bollingerMid, .bollingerUpper, .bollingerLower,
                 .bollinger50Mid, .bollinger50Upper, .bollinger50Lower,
                 .donchianUpper, .donchianLower, .donchian55Upper, .donchian55Lower,
                 .keltnerMid, .keltnerUpper, .keltnerLower,
                 .atrUpper, .atrLower, .regressionMid, .regressionUpper, .regressionLower,
                 .volatilityConeMid, .volatilityConeUpper, .volatilityConeLower:
                continue
            }
        }

        return overlays
    }

    private func overlaysForSeries(
        _ series: [IndicatorPoint],
        indicator: ForesightIndicator,
        visibleDomain: ClosedRange<Date>,
        futureUpperBound: Date
    ) -> [IndicatorOverlay] {
        let visibleSeries = clippedIndicatorSeries(series, to: visibleDomain)
        guard visibleSeries.count > 1 else { return [] }

        return [
            IndicatorOverlay(
                id: "\(indicator.id)-live",
                label: indicator.tooltipTitle,
                color: indicator.color,
                lineWidth: indicator.lineWidth,
                dashed: false,
                points: visibleSeries
            )
        ]
    }

    private func futureOverlaysForSeries(
        _ series: [IndicatorPoint],
        indicator: ForesightIndicator,
        latestActualDate: Date?,
        futureUpperBound: Date
    ) -> [IndicatorOverlay] {
        guard foresightRange != .off,
              let latestActualDate,
              futureUpperBound > latestActualDate else { return [] }

        let futureSeries = clippedFutureIndicatorSeries(
            series,
            from: latestActualDate,
            to: futureUpperBound
        )
        guard futureSeries.count > 1 else { return [] }

        return [
            IndicatorOverlay(
                id: "\(indicator.id)-future",
                label: indicator.tooltipTitle,
                color: indicator.color.opacity(0.88),
                lineWidth: indicator.lineWidth,
                dashed: true,
                points: futureSeries
            )
        ]
    }

    private func emaSeries(period: Int, points: [GraphPoint]) -> [IndicatorPoint] {
        guard points.count >= period else { return [] }

        let multiplier = 2.0 / Double(period + 1)
        let seed = points.prefix(period).map(\.value).reduce(0, +) / Double(period)
        var currentEMA = seed
        var result: [IndicatorPoint] = [
            IndicatorPoint(date: points[period - 1].date, value: currentEMA)
        ]

        for point in points.dropFirst(period) {
            currentEMA = ((point.value - currentEMA) * multiplier) + currentEMA
            result.append(IndicatorPoint(date: point.date, value: currentEMA))
        }

        return result
    }

    private func smaSeries(period: Int, points: [GraphPoint]) -> [IndicatorPoint] {
        guard points.count >= period else { return [] }

        var rollingSum = points.prefix(period).map(\.value).reduce(0, +)
        var result: [IndicatorPoint] = [
            IndicatorPoint(date: points[period - 1].date, value: rollingSum / Double(period))
        ]

        for index in period..<points.count {
            rollingSum += points[index].value
            rollingSum -= points[index - period].value
            result.append(
                IndicatorPoint(
                    date: points[index].date,
                    value: rollingSum / Double(period)
                )
            )
        }

        return result
    }

    private func wmaSeries(period: Int, points: [GraphPoint]) -> [IndicatorPoint] {
        guard points.count >= period else { return [] }

        let weightTotal = Double(period * (period + 1)) / 2.0
        var result: [IndicatorPoint] = []
        result.reserveCapacity(points.count - period + 1)

        for index in (period - 1)..<points.count {
            var weightedSum = 0.0
            let start = index - period + 1

            for offset in 0..<period {
                weightedSum += points[start + offset].value * Double(offset + 1)
            }

            result.append(IndicatorPoint(date: points[index].date, value: weightedSum / weightTotal))
        }

        return result
    }

    private func hmaSeries(period: Int, points: [GraphPoint]) -> [IndicatorPoint] {
        guard points.count >= period else { return [] }

        let halfPeriod = max(period / 2, 1)
        let sqrtPeriod = max(Int(round(sqrt(Double(period)))), 1)
        let half = wmaSeries(period: halfPeriod, points: points)
        let full = wmaSeries(period: period, points: points)
        let halfByDate = Dictionary(uniqueKeysWithValues: half.map { ($0.date.timeIntervalSince1970, $0.value) })

        let rawBase: [GraphPoint] = full.compactMap { (point: IndicatorPoint) -> GraphPoint? in
            guard let halfValue = halfByDate[point.date.timeIntervalSince1970] else { return nil }
            return GraphPoint(
                index: 0,
                date: point.date,
                value: (2 * halfValue) - point.value,
                volume: nil
            )
        }

        let rawPoints = rawBase.enumerated().map { index, point in
            GraphPoint(index: index, date: point.date, value: point.value, volume: point.volume)
        }

        return wmaSeries(period: sqrtPeriod, points: rawPoints)
    }

    private func previousCloseSeries(
        points: [GraphPoint],
        visibleDomain: ClosedRange<Date>,
        futureUpperBound: Date
    ) -> [IndicatorPoint] {
        guard points.count > 1 else { return [] }

        let firstVisibleIndex = points.firstIndex { $0.date >= visibleDomain.lowerBound } ?? points.indices.last
        guard let firstVisibleIndex else { return [] }

        var sessionStartIndex = firstVisibleIndex
        while sessionStartIndex > points.startIndex,
              !shouldResetSessionCalculation(from: points[sessionStartIndex - 1], to: points[sessionStartIndex]) {
            sessionStartIndex -= 1
        }

        let closeIndex: Int?
        if sessionStartIndex > points.startIndex {
            closeIndex = points.index(before: sessionStartIndex)
        } else if firstVisibleIndex > points.startIndex {
            closeIndex = points.index(before: firstVisibleIndex)
        } else {
            closeIndex = nil
        }
        guard let closeIndex, points.indices.contains(closeIndex) else { return [] }

        let value = points[closeIndex].value
        return [
            IndicatorPoint(date: visibleDomain.lowerBound, value: value),
            IndicatorPoint(date: futureUpperBound, value: value)
        ]
    }

    private func vwapSeries(points: [GraphPoint]) -> [IndicatorPoint] {
        guard !points.isEmpty else { return [] }

        var weightedValue = 0.0
        var totalWeight = 0.0
        var fallbackSum = 0.0
        var sessionSampleCount = 0
        var result: [IndicatorPoint] = []
        result.reserveCapacity(points.count)

        for (index, point) in points.enumerated() {
            if index > 0, shouldResetSessionCalculation(from: points[index - 1], to: point) {
                weightedValue = 0
                totalWeight = 0
                fallbackSum = 0
                sessionSampleCount = 0
            }

            sessionSampleCount += 1
            let volumeWeight = max(point.volume ?? 0, 0)
            if volumeWeight > 0 {
                weightedValue += point.value * volumeWeight
                totalWeight += volumeWeight
            } else {
                fallbackSum += point.value
            }

            let value: Double
            if totalWeight > 0 {
                value = weightedValue / totalWeight
            } else {
                value = fallbackSum / Double(max(sessionSampleCount, 1))
            }

            result.append(IndicatorPoint(date: point.date, value: value))
        }

        return result
    }

    private func bollingerBands(
        period: Int,
        points: [GraphPoint]
    ) -> (mid: [IndicatorPoint], upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        guard points.count >= period else { return ([], [], []) }

        var mid: [IndicatorPoint] = []
        var upper: [IndicatorPoint] = []
        var lower: [IndicatorPoint] = []
        mid.reserveCapacity(points.count - period + 1)
        upper.reserveCapacity(points.count - period + 1)
        lower.reserveCapacity(points.count - period + 1)

        for index in (period - 1)..<points.count {
            let window = points[(index - period + 1)...index].map(\.value)
            let mean = window.reduce(0, +) / Double(period)
            let variance = window.reduce(0) { partial, value in
                partial + pow(value - mean, 2)
            } / Double(period)
            let stdDev = sqrt(variance)
            let date = points[index].date

            mid.append(IndicatorPoint(date: date, value: mean))
            upper.append(IndicatorPoint(date: date, value: mean + (stdDev * 2)))
            lower.append(IndicatorPoint(date: date, value: mean - (stdDev * 2)))
        }

        return (mid, upper, lower)
    }

    private func donchianChannel(
        period: Int,
        points: [GraphPoint]
    ) -> (upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        guard points.count >= period else { return ([], []) }

        var upper: [IndicatorPoint] = []
        var lower: [IndicatorPoint] = []
        upper.reserveCapacity(points.count - period + 1)
        lower.reserveCapacity(points.count - period + 1)

        for index in (period - 1)..<points.count {
            let window = points[(index - period + 1)...index].map(\.value)
            let date = points[index].date
            upper.append(IndicatorPoint(date: date, value: window.max() ?? points[index].value))
            lower.append(IndicatorPoint(date: date, value: window.min() ?? points[index].value))
        }

        return (upper, lower)
    }

    private func keltnerChannel(
        period: Int,
        multiplier: Double,
        points: [GraphPoint]
    ) -> (mid: [IndicatorPoint], upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        guard points.count >= period else { return ([], [], []) }

        let mid = emaSeries(period: period, points: points)
        guard !mid.isEmpty else { return ([], [], []) }

        var rangeValues: [Double] = [0]
        rangeValues.reserveCapacity(points.count)

        for index in points.indices.dropFirst() {
            let previous = points[index - 1]
            let current = points[index]
            let range = shouldResetSessionCalculation(from: previous, to: current)
                ? 0
                : abs(current.value - previous.value)
            rangeValues.append(range)
        }

        var atrSeries: [Double] = []
        atrSeries.reserveCapacity(points.count - period + 1)
        var rollingRange = rangeValues.prefix(period).reduce(0, +)
        atrSeries.append(rollingRange / Double(period))

        if points.count > period {
            for index in period..<points.count {
                rollingRange += rangeValues[index]
                rollingRange -= rangeValues[index - period]
                atrSeries.append(rollingRange / Double(period))
            }
        }

        let alignedCount = min(mid.count, atrSeries.count)
        guard alignedCount > 0 else { return ([], [], []) }

        var upper: [IndicatorPoint] = []
        var lower: [IndicatorPoint] = []
        upper.reserveCapacity(alignedCount)
        lower.reserveCapacity(alignedCount)

        for index in 0..<alignedCount {
            let midPoint = mid[index]
            let bandOffset = atrSeries[index] * multiplier
            upper.append(IndicatorPoint(date: midPoint.date, value: midPoint.value + bandOffset))
            lower.append(IndicatorPoint(date: midPoint.date, value: midPoint.value - bandOffset))
        }

        return (Array(mid.prefix(alignedCount)), upper, lower)
    }

    private func atrBands(
        period: Int,
        multiplier: Double,
        points: [GraphPoint]
    ) -> (upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        let channel = keltnerChannel(period: period, multiplier: multiplier, points: points)
        return (channel.upper, channel.lower)
    }

    private func regressionChannel(
        period: Int,
        points: [GraphPoint]
    ) -> (mid: [IndicatorPoint], upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        guard period > 1, points.count >= period else { return ([], [], []) }

        let xValues = (0..<period).map(Double.init)
        let xMean = xValues.reduce(0, +) / Double(period)
        let xVariance = xValues.reduce(0) { partial, value in
            partial + pow(value - xMean, 2)
        }

        var mid: [IndicatorPoint] = []
        var upper: [IndicatorPoint] = []
        var lower: [IndicatorPoint] = []
        mid.reserveCapacity(points.count - period + 1)
        upper.reserveCapacity(points.count - period + 1)
        lower.reserveCapacity(points.count - period + 1)

        for index in (period - 1)..<points.count {
            let window = Array(points[(index - period + 1)...index])
            let yValues = window.map(\.value)
            let yMean = yValues.reduce(0, +) / Double(period)
            let covariance = zip(xValues, yValues).reduce(0) { partial, sample in
                partial + ((sample.0 - xMean) * (sample.1 - yMean))
            }
            let slope = xVariance > 0 ? covariance / xVariance : 0
            let intercept = yMean - slope * xMean
            let fitted = intercept + slope * Double(period - 1)
            let residualStdDev = sqrt(
                zip(xValues, yValues).reduce(0) { partial, sample in
                    let estimate = intercept + slope * sample.0
                    return partial + pow(sample.1 - estimate, 2)
                } / Double(period)
            )
            let date = points[index].date

            mid.append(IndicatorPoint(date: date, value: fitted))
            upper.append(IndicatorPoint(date: date, value: fitted + residualStdDev * 2))
            lower.append(IndicatorPoint(date: date, value: fitted - residualStdDev * 2))
        }

        return (mid, upper, lower)
    }

    private func trendDriftProjection(
        points: [GraphPoint],
        futureUpperBound: Date
    ) -> [IndicatorPoint] {
        guard let lastPoint = points.last else { return [] }

        let window = Array(points.suffix(min(max(12, points.count / 3), 48)))
        let dates = projectionDates(from: points, to: futureUpperBound)
        guard window.count > 1, dates.count > 1 else { return [] }

        let slope = projectedSlope(for: window) * 0.9
        return dates.enumerated().map { index, date in
            IndicatorPoint(
                date: date,
                value: lastPoint.value + (slope * Double(index))
            )
        }
    }

    private func meanReversionProjection(
        points: [GraphPoint],
        futureUpperBound: Date
    ) -> [IndicatorPoint] {
        guard let lastPoint = points.last else { return [] }

        let dates = projectionDates(from: points, to: futureUpperBound)
        guard dates.count > 1 else { return [] }

        let anchor = emaSeries(period: min(max(12, points.count / 4), 20), points: points).last?.value
            ?? smaSeries(period: min(max(8, points.count / 5), 20), points: points).last?.value
            ?? lastPoint.value
        let drift = projectedSlope(for: Array(points.suffix(min(max(8, points.count / 4), 24)))) * 0.2

        return dates.enumerated().map { index, date in
            let progress = Double(index) / Double(max(dates.count - 1, 1))
            let reversion = 1 - exp(-2.8 * progress)
            let value = lastPoint.value
                + ((anchor - lastPoint.value) * reversion)
                + (drift * Double(index))
            return IndicatorPoint(date: date, value: value)
        }
    }

    private func vwapCarryProjection(
        points: [GraphPoint],
        futureUpperBound: Date
    ) -> [IndicatorPoint] {
        guard !points.isEmpty else { return [] }

        let dates = projectionDates(from: points, to: futureUpperBound)
        guard dates.count > 1 else { return [] }

        let anchor = vwapSeries(points: points).last?.value ?? points.last?.value ?? 0
        return dates.map { date in
            IndicatorPoint(date: date, value: anchor)
        }
    }

    private func volatilityConeProjection(
        points: [GraphPoint],
        futureUpperBound: Date
    ) -> (mid: [IndicatorPoint], upper: [IndicatorPoint], lower: [IndicatorPoint]) {
        let mid = trendDriftProjection(points: points, futureUpperBound: futureUpperBound)
        guard mid.count > 1 else { return ([], [], []) }

        let deltas = zip(points.dropFirst(), points).map { current, previous in
            abs(current.value - previous.value)
        }
        let recentDeltas = Array(deltas.suffix(min(max(10, deltas.count / 3), 40)))
        let averageDelta = recentDeltas.isEmpty
            ? max((points.last?.value ?? 1) * 0.0015, 0.01)
            : recentDeltas.reduce(0, +) / Double(recentDeltas.count)
        let baseBand = max(averageDelta * 1.6, max((points.last?.value ?? 1) * 0.0015, 0.01))

        let upper = mid.enumerated().map { index, point in
            let progress = Double(index) / Double(max(mid.count - 1, 1))
            let expansion = 0.65 + (sqrt(progress) * 1.55)
            return IndicatorPoint(date: point.date, value: point.value + (baseBand * expansion))
        }
        let lower = mid.enumerated().map { index, point in
            let progress = Double(index) / Double(max(mid.count - 1, 1))
            let expansion = 0.65 + (sqrt(progress) * 1.55)
            return IndicatorPoint(date: point.date, value: point.value - (baseBand * expansion))
        }

        return (mid, upper, lower)
    }

    private func projectionDates(
        from points: [GraphPoint],
        to futureUpperBound: Date
    ) -> [Date] {
        guard let lastDate = points.last?.date, futureUpperBound > lastDate else { return [] }

        let totalDuration = futureUpperBound.timeIntervalSince(lastDate)
        let intervals = zip(points.dropFirst(), points).map { current, previous in
            max(current.date.timeIntervalSince(previous.date), 0)
        }.filter { $0 > 0 }
        let recentIntervals = Array(intervals.suffix(12)).sorted()
        let cadence = recentIntervals.isEmpty
            ? totalDuration / 18
            : recentIntervals[recentIntervals.count / 2]
        let estimatedCount = Int(ceil(totalDuration / max(cadence, 1)))
        let stepCount = max(8, min(28, estimatedCount))

        return (0...stepCount).map { step in
            lastDate.addingTimeInterval((totalDuration * Double(step)) / Double(stepCount))
        }
    }

    private func projectedSlope(for points: [GraphPoint]) -> Double {
        guard points.count > 1 else { return 0 }

        let xValues = (0..<points.count).map(Double.init)
        let yValues = points.map(\.value)
        let xMean = xValues.reduce(0, +) / Double(xValues.count)
        let yMean = yValues.reduce(0, +) / Double(yValues.count)
        let numerator = zip(xValues, yValues).reduce(0) { partial, sample in
            partial + ((sample.0 - xMean) * (sample.1 - yMean))
        }
        let denominator = xValues.reduce(0) { partial, value in
            partial + pow(value - xMean, 2)
        }

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    private func shouldResetSessionCalculation(from previous: GraphPoint, to current: GraphPoint) -> Bool {
        instrumentType == .equity
            && current.date.timeIntervalSince(previous.date) > adaptiveMaximumRenderableGap
    }

    private func axisLabelOverlay(
        size: CGSize,
        xDomain: ClosedRange<Date>,
        xProjection: XAxisProjection?,
        yAxis: YAxisConfiguration,
        xTicks: [Date],
        labels: [Date: String]
    ) -> some View {
        let plot = plotRect(in: size)

        return ZStack(alignment: .topLeading) {
            ForEach(yAxis.ticks, id: \.self) { tick in
                Text(formatYAxisValue(tick, step: yAxis.step))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(width: 54, alignment: .trailing)
                    .position(
                        x: plot.minX - 34,
                        y: yPosition(for: tick, in: plot, yDomain: yAxis.domain)
                    )
            }

            ForEach(xTicks, id: \.timeIntervalSince1970) { tick in
                Text(labels[tick] ?? Self.timeFormatter.string(from: tick))
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 74)
                    .position(
                        x: xPosition(for: tick, in: plot, xDomain: xDomain, projection: xProjection),
                        y: plot.maxY + 24
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private func hoverOverlay(
        point: GraphPoint,
        indicatorOverlays: [IndicatorOverlay],
        plot: CGRect,
        xDomain: ClosedRange<Date>,
        xProjection: XAxisProjection?,
        yAxis: YAxisConfiguration
    ) -> some View {
        let location = position(for: point, in: plot, xDomain: xDomain, projection: xProjection, yDomain: yAxis.domain)
        let tooltipX = min(max(location.x + 88, plot.minX + 96), plot.maxX - 96)
        let tooltipY = min(max(location.y - 46, plot.minY + 34), plot.maxY - 34)
        let indicatorValues = hoverIndicatorValues(for: point.date, overlays: indicatorOverlays)

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: location.x, y: plot.minY))
                path.addLine(to: CGPoint(x: location.x, y: plot.maxY))
            }
            .stroke(.white.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))

            Circle()
                .fill(.white.opacity(0.96))
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 0.75))
                .position(location)

            VStack(alignment: .leading, spacing: 4) {
                Text(point.value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.94))

                Text(Self.hoverFormatter.string(from: point.date))
                    .font(.system(size: 10.5, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.48))

                if !indicatorValues.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(indicatorValues) { indicatorValue in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(indicatorValue.color)
                                        .frame(width: 6, height: 6)

                                    Text(indicatorValue.label)
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.68))

                                    Spacer(minLength: 8)

                                    Text(indicatorValue.formattedValue)
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.90))
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 164)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.095, blue: 0.11).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .position(x: tooltipX, y: tooltipY)
        }
        .allowsHitTesting(false)
    }

    private func hoverIndicatorValues(
        for date: Date,
        overlays: [IndicatorOverlay]
    ) -> [HoverIndicatorValue] {
        overlays.compactMap { overlay in
            guard let value = interpolatedIndicatorValue(in: overlay, at: date) else { return nil }
            return HoverIndicatorValue(
                id: overlay.id,
                label: overlay.label,
                formattedValue: value.formatted(.number.precision(.fractionLength(2))),
                color: overlay.color
            )
        }
    }

    private func interpolatedIndicatorValue(
        in overlay: IndicatorOverlay,
        at date: Date
    ) -> Double? {
        guard let first = overlay.points.first, let last = overlay.points.last else { return nil }
        guard date >= first.date, date <= last.date else { return nil }

        if let exact = overlay.points.first(where: { abs($0.date.timeIntervalSince(date)) < 0.5 }) {
            return exact.value
        }

        for index in 1..<overlay.points.count {
            let previous = overlay.points[index - 1]
            let current = overlay.points[index]

            if date <= current.date {
                let span = current.date.timeIntervalSince(previous.date)
                guard span > 0 else { return current.value }
                let progress = date.timeIntervalSince(previous.date) / span
                return previous.value + ((current.value - previous.value) * progress)
            }
        }

        return last.value
    }

    private func position(
        for point: GraphPoint,
        in plot: CGRect,
        xDomain: ClosedRange<Date>,
        projection: XAxisProjection?,
        yDomain: ClosedRange<Double>
    ) -> CGPoint {
        let x = xPosition(for: point.date, in: plot, xDomain: xDomain, projection: projection)
        let y = yPosition(for: point.value, in: plot, yDomain: yDomain)
        return CGPoint(x: x, y: y)
    }

    private func xPosition(
        for date: Date,
        in plot: CGRect,
        xDomain: ClosedRange<Date>,
        projection: XAxisProjection?
    ) -> CGFloat {
        let progress: Double
        if let projection {
            progress = projection.progress(for: date)
        } else {
            let span = max(xDomain.upperBound.timeIntervalSince(xDomain.lowerBound), 1)
            progress = date.timeIntervalSince(xDomain.lowerBound) / span
        }
        return plot.minX + CGFloat(progress.clamped(to: 0...1)) * plot.width
    }

    private func yPosition(for value: Double, in plot: CGRect, yDomain: ClosedRange<Double>) -> CGFloat {
        let span = max(yDomain.upperBound - yDomain.lowerBound, 0.0001)
        let progress = (value - yDomain.lowerBound) / span
        return plot.maxY - CGFloat(progress.clamped(to: 0...1)) * plot.height
    }

    private func nearestPoint(
        to location: CGPoint?,
        in plot: CGRect,
        points: [GraphPoint],
        xDomain: ClosedRange<Date>,
        projection: XAxisProjection?
    ) -> GraphPoint? {
        guard
            let location,
            plot.insetBy(dx: -10, dy: -18).contains(location),
            !points.isEmpty
        else {
            return nil
        }

        if let latestDate = points.last?.date {
            let latestX = xPosition(for: latestDate, in: plot, xDomain: xDomain, projection: projection)
            if location.x > latestX + 8 {
                return nil
            }
        }

        let rawProgress = Double((location.x - plot.minX) / max(plot.width, 1))
        let progress = rawProgress.clamped(to: 0...1)
        let targetTime: TimeInterval
        if let projection {
            targetTime = projection.date(at: progress).timeIntervalSince1970
        } else {
            targetTime = xDomain.lowerBound.timeIntervalSince1970
                + xDomain.upperBound.timeIntervalSince(xDomain.lowerBound) * progress
        }

        return points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince1970 - targetTime) < abs(rhs.date.timeIntervalSince1970 - targetTime)
        }
    }

    private func refreshChartCamera(animated: Bool) {
        guard let targetXDomain = targetXDomain() else {
            displayedXDomain = nil
            displayedYAxis = yAxisConfiguration
            lastCameraRange = selectedRange
            return
        }

        let isRangeReset = lastCameraRange != selectedRange
        let isLargeJump = shouldResetCamera(to: targetXDomain)
        let targetYAxis = smoothedYAxisConfiguration(reset: isRangeReset || isLargeJump)

        let applyCamera = {
            displayedXDomain = targetXDomain
            displayedYAxis = targetYAxis
            lastCameraRange = selectedRange
        }

        if animated, !isRangeReset, !isLargeJump {
            withAnimation(.linear(duration: scrollAnimationDuration(to: targetXDomain))) {
                applyCamera()
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                applyCamera()
            }
        }
    }

    private func targetXDomain() -> ClosedRange<Date>? {
        guard let latestDate = points.last?.date else { return nil }
        let upperBound = latestDate.addingTimeInterval(foresightRange.duration)

        if instrumentType == .equity,
           let equityDomain = equityTargetXDomain(latestDate: latestDate, upperBound: upperBound) {
            return equityDomain
        }

        let lowerBound = latestDate.addingTimeInterval(-selectedRange.marketTimeRange.duration)
        return lowerBound...upperBound
    }

    private func equityTargetXDomain(latestDate: Date, upperBound: Date) -> ClosedRange<Date>? {
        let ordered = chartRenderablePoints()
        guard
            let firstDate = ordered.first?.date,
            firstDate < latestDate
        else {
            return nil
        }

        let duration = selectedRange.marketTimeRange.duration
        let dataSpan = latestDate.timeIntervalSince(firstDate)
        let shouldUseDataSpan = selectedRange == .day
            || selectedRange == .week
            || selectedRange == .month
            || selectedRange == .quarter
            || selectedRange == .year
            || dataSpan < duration * 0.85

        guard shouldUseDataSpan else {
            return nil
        }

        let padding = min(max(dataSpan * 0.025, 60), duration * 0.05)
        return firstDate.addingTimeInterval(-padding)...upperBound
    }

    private func fallbackXDomain() -> ClosedRange<Date> {
        let upperBound = Date().addingTimeInterval(foresightRange.duration)
        return upperBound.addingTimeInterval(-selectedRange.marketTimeRange.duration)...upperBound
    }

    private func shouldResetCamera(to target: ClosedRange<Date>) -> Bool {
        guard let displayedXDomain else { return true }

        let shift = abs(target.upperBound.timeIntervalSince(displayedXDomain.upperBound))
        let resetThreshold = max(
            selectedRange.marketTimeRange.duration * 0.08,
            medianPointCadence * 6
        )
        return shift > resetThreshold
    }

    private func scrollAnimationDuration(to target: ClosedRange<Date>) -> TimeInterval {
        guard let displayedXDomain else { return 0.28 }

        let shift = abs(target.upperBound.timeIntervalSince(displayedXDomain.upperBound))
        let cadence = max(medianPointCadence, 1)
        let normalized = min(max(shift / cadence, 0.55), 1.25)
        return 0.14 * normalized
    }

    private func smoothedYAxisConfiguration(reset: Bool) -> YAxisConfiguration {
        let target = yAxisConfiguration
        guard !reset, let current = displayedYAxis else {
            return target
        }

        let targetDomain = target.domain
        let currentDomain = current.domain
        let currentSpan = currentDomain.upperBound - currentDomain.lowerBound
        let targetSpan = max(targetDomain.upperBound - targetDomain.lowerBound, 0.0001)
        let targetFitsCurrent = targetDomain.lowerBound >= currentDomain.lowerBound
            && targetDomain.upperBound <= currentDomain.upperBound

        // Preserve the existing axis only while the target is expanding or staying
        // effectively the same. If the required range contracts, snap back so the
        // chart does not keep stale headroom after indicators are removed.
        if targetSpan >= currentSpan, targetFitsCurrent, currentSpan <= targetSpan * 1.8 {
            return current
        }

        return target
    }

    private var medianPointCadence: TimeInterval {
        let gaps = zip(points.dropFirst(), points)
            .map { current, previous in current.date.timeIntervalSince(previous.date) }
            .filter { $0.isFinite && $0 > 0 }

        guard !gaps.isEmpty else {
            return max(selectedRange.marketTimeRange.duration / Double(max(points.count, 2)), 1)
        }

        let sorted = gaps.sorted()
        return sorted[sorted.count / 2]
    }

    private func adaptiveXAxisTicks(
        plotWidth: CGFloat,
        domain: ClosedRange<Date>,
        projection: XAxisProjection?
    ) -> [Date] {
        let first = domain.lowerBound
        let last = domain.upperBound

        let availableWidth = max(plotWidth - 70, 320)
        let maxTickCount = max(3, min(10, Int(availableWidth / 95)))
        let preferredTickCount: Int = switch selectedRange {
        case .twentyFiveMinutes: 6
        case .hour: 6
        case .day: 7
        case .week: 8
        case .month: 7
        case .quarter: 6
        case .year: 6
        }
        let targetCount = max(3, min(maxTickCount, preferredTickCount))

        if let projection {
            let projectedTicks = projection.tickDates(targetCount: targetCount)
            if projectedTicks.count >= 2 {
                return projectedTicks
            }
        }

        let totalSeconds = last.timeIntervalSince(first)
        let rawStep = totalSeconds / Double(max(targetCount - 1, 1))
        let step = timeStep(for: rawStep)

        let startTS = first.timeIntervalSince1970
        let endTS = last.timeIntervalSince1970
        let firstAligned = ceil(startTS / step) * step
        let lastAligned = floor(endTS / step) * step

        var tickDates: [Date] = []
        if firstAligned <= lastAligned {
            var current = firstAligned
            while current <= lastAligned + 0.001 {
                tickDates.append(Date(timeIntervalSince1970: current))
                current += step
            }
        }

        if tickDates.count < 2 {
            return [first, last]
        }

        return tickDates
    }

    private func chartRenderablePoints() -> [GraphPoint] {
        var ordered = points
        if !isSortedByDate(ordered) {
            ordered.sort { $0.date < $1.date }
        }
        guard !ordered.isEmpty else { return [] }

        var deduped: [GraphPoint] = []
        deduped.reserveCapacity(ordered.count)

        for point in ordered {
            if let last = deduped.last, last.date == point.date {
                deduped[deduped.count - 1] = point
            } else {
                deduped.append(point)
            }
        }

        return deduped
    }

    private func indicatorRenderablePoints() -> [GraphPoint] {
        var ordered = indicatorPoints
        if !isSortedByDate(ordered) {
            ordered.sort { $0.date < $1.date }
        }
        guard !ordered.isEmpty else { return [] }

        var deduped: [GraphPoint] = []
        deduped.reserveCapacity(ordered.count)

        for (displayIndex, point) in ordered.enumerated() {
            let normalizedPoint = GraphPoint(
                index: displayIndex,
                date: point.date,
                value: point.value,
                volume: point.volume
            )

            if let last = deduped.last, last.date == point.date {
                deduped[deduped.count - 1] = normalizedPoint
            } else {
                deduped.append(normalizedPoint)
            }
        }

        return deduped
    }

    private func clippedIndicatorSeries(
        _ series: [IndicatorPoint],
        to visibleDomain: ClosedRange<Date>
    ) -> [IndicatorPoint] {
        guard !series.isEmpty else { return [] }

        var clipped: [IndicatorPoint] = []
        clipped.reserveCapacity(series.count)
        var previous: IndicatorPoint?

        for point in series {
            if point.date < visibleDomain.lowerBound {
                previous = point
                continue
            }

            if point.date > visibleDomain.upperBound {
                break
            }

            if clipped.isEmpty, let previous {
                clipped.append(IndicatorPoint(date: visibleDomain.lowerBound, value: previous.value))
            }
            clipped.append(point)
        }

        if clipped.isEmpty,
           let previous,
           let firstAfter = series.first(where: { $0.date > visibleDomain.lowerBound }) {
            clipped.append(IndicatorPoint(date: visibleDomain.lowerBound, value: previous.value))
            clipped.append(firstAfter)
        }

        return clipped
    }

    private func clippedFutureIndicatorSeries(
        _ series: [IndicatorPoint],
        from startDate: Date,
        to endDate: Date
    ) -> [IndicatorPoint] {
        guard !series.isEmpty, endDate > startDate else { return [] }

        var clipped: [IndicatorPoint] = []
        clipped.reserveCapacity(series.count)
        var previous: IndicatorPoint?

        for point in series {
            if point.date < startDate {
                previous = point
                continue
            }

            if point.date > endDate {
                break
            }

            if clipped.isEmpty, let previous {
                clipped.append(IndicatorPoint(date: startDate, value: previous.value))
            }
            clipped.append(point)
        }

        if clipped.isEmpty,
           let previous,
           let firstAfter = series.first(where: { $0.date > startDate }) {
            clipped.append(IndicatorPoint(date: startDate, value: previous.value))
            clipped.append(firstAfter)
        }

        if let last = clipped.last, last.date < endDate {
            clipped.append(IndicatorPoint(date: endDate, value: last.value))
        }

        return clipped
    }

    private func segmentedRenderablePoints(from points: [GraphPoint]) -> [[GraphPoint]] {
        guard points.count > 1 else { return points.isEmpty ? [] : [points] }

        let gapLimit = adaptiveMaximumRenderableGap
        var segments: [[GraphPoint]] = []
        var current: [GraphPoint] = []
        current.reserveCapacity(points.count)

        for point in points {
            if let last = current.last,
               point.date.timeIntervalSince(last.date) > gapLimit {
                if !current.isEmpty {
                    segments.append(current)
                }
                current = [point]
            } else {
                current.append(point)
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }

        return segments
    }

    private func segmentedIndicatorPoints(from points: [IndicatorPoint]) -> [[IndicatorPoint]] {
        guard points.count > 1 else { return points.isEmpty ? [] : [points] }

        let gapLimit = adaptiveMaximumRenderableGap
        var segments: [[IndicatorPoint]] = []
        var current: [IndicatorPoint] = []
        current.reserveCapacity(points.count)

        for point in points {
            if let last = current.last,
               point.date.timeIntervalSince(last.date) > gapLimit {
                if !current.isEmpty {
                    segments.append(current)
                }
                current = [point]
            } else {
                current.append(point)
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }

        return segments
    }

    private func makeXAxisProjection(
        domain: ClosedRange<Date>,
        pointSegments: [[GraphPoint]]
    ) -> XAxisProjection? {
        guard instrumentType == .equity, pointSegments.count > 0 else { return nil }

        let sessionSeparator = min(max(medianPointCadence, 60), 3 * 60)
        var intervals: [XAxisProjection.Interval] = []
        var cursor: TimeInterval = 0

        for segment in pointSegments {
            guard
                let first = segment.first?.date,
                let last = segment.last?.date
            else {
                continue
            }

            let actualStart = max(first, domain.lowerBound)
            let actualEnd = min(last, domain.upperBound)
            guard actualEnd >= actualStart else { continue }

            if !intervals.isEmpty {
                cursor += sessionSeparator
            }

            let duration = max(actualEnd.timeIntervalSince(actualStart), medianPointCadence)
            intervals.append(
                XAxisProjection.Interval(
                    actualStart: actualStart,
                    actualEnd: actualEnd,
                    projectedStart: cursor,
                    projectedEnd: cursor + duration
                )
            )
            cursor += duration
        }

        guard !intervals.isEmpty, cursor > 0 else { return nil }

        if let last = intervals.last, domain.upperBound > last.actualEnd {
            cursor += domain.upperBound.timeIntervalSince(last.actualEnd)
        }

        return XAxisProjection(intervals: intervals, totalDuration: max(cursor, 1))
    }

    private func drawSessionGapMarkers(
        context: inout GraphicsContext,
        pointSegments: [[GraphPoint]],
        plot: CGRect,
        xDomain: ClosedRange<Date>,
        projection: XAxisProjection?
    ) {
        guard instrumentType == .equity, pointSegments.count > 1 else { return }

        for segment in pointSegments.dropFirst() {
            guard let first = segment.first else { continue }
            let x = xPosition(for: first.date, in: plot, xDomain: xDomain, projection: projection)
            var marker = Path()
            marker.move(to: CGPoint(x: x, y: plot.maxY - 10))
            marker.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(
                marker,
                with: .color(.white.opacity(0.11)),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
            )
        }
    }

    private func isSortedByDate(_ points: [GraphPoint]) -> Bool {
        guard points.count > 1 else { return true }

        for index in points.indices.dropFirst() {
            if points[index - 1].date > points[index].date {
                return false
            }
        }

        return true
    }

    private var adaptiveMaximumRenderableGap: TimeInterval {
        let gaps = zip(points.dropFirst(), points)
            .map { current, previous in current.date.timeIntervalSince(previous.date) }
            .filter { $0.isFinite && $0 > 0 }

        guard !gaps.isEmpty else { return maximumRenderableGap }

        let sorted = gaps.sorted()
        let medianGap = sorted[sorted.count / 2]
        let cadenceAwareLimit = max(maximumRenderableGap, medianGap * 2.75)
        return min(cadenceAwareLimit, selectedRange.marketTimeRange.duration / 3)
    }

    private var maximumRenderableGap: TimeInterval {
        switch selectedRange {
        case .twentyFiveMinutes:
            return 90
        case .hour:
            return 6 * 60
        case .day:
            return 2 * 60 * 60
        case .week:
            return 90 * 60
        case .month:
            return 8 * 60 * 60
        case .quarter:
            return 36 * 60 * 60
        case .year:
            return 7 * 24 * 60 * 60
        }
    }

    private func makeXAxisLabels(from ticks: [Date]) -> [Date: String] {
        guard !ticks.isEmpty else { return [:] }

        let calendar = Calendar.current
        var previousDay: Date?
        var labels: [Date: String] = [:]

        for tick in ticks {
            let day = calendar.startOfDay(for: tick)
            let timeLabel = Self.timeFormatter.string(from: tick)

            if let previousDay, day != previousDay {
                let dayLabel = Self.dayPrefixFormatter.string(from: tick)
                labels[tick] = "\(dayLabel)\n\(timeLabel)"
            } else {
                labels[tick] = timeLabel
            }

            previousDay = day
        }

        return labels
    }

    private func niceStep(for rawStep: Double) -> Double {
        guard rawStep.isFinite, rawStep > 0 else { return 1 }

        let exponent = floor(log10(rawStep))
        let magnitude = pow(10, exponent)
        let fraction = rawStep / magnitude

        let niceFraction: Double
        switch fraction {
        case ..<1.5: niceFraction = 1
        case ..<3.5: niceFraction = 2
        case ..<7.5: niceFraction = 5
        default: niceFraction = 10
        }

        return niceFraction * magnitude
    }

    private func timeStep(for rawSeconds: Double) -> TimeInterval {
        let candidates: [TimeInterval] = [
            15, 30,
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 14400, 21600, 43200,
            86400, 172800, 604800, 1_209_600, 2_592_000
        ]
        return candidates.first(where: { $0 >= rawSeconds }) ?? 2_592_000
    }

    private func formatYAxisValue(_ value: Double, step: Double) -> String {
        let decimals = max(0, min(4, Int(ceil(-log10(max(step, 0.0001))))))
        return value.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(decimals))
        )
    }
}

private struct ChartTopControls: View {
    @ObservedObject var market: AeviumMarketViewModel
    @ObservedObject var watchlist: InstrumentWatchlistStore
    @Binding var selectedRange: ChartRange
    let isInspectorOpen: Bool
    let onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            InstrumentSearchControl(market: market)
            watchlistToggle
            AeviumRangeSelector(selectedRange: $selectedRange)

            Button(action: onToggleInspector) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
            }
            .buttonStyle(.plain)
            .help(isInspectorOpen ? "Hide inspector" : "Show inspector")
        }
        .fixedSize(horizontal: true, vertical: false)
        .compositingGroup()
    }

    private var watchlistToggle: some View {
        let isSaved = watchlist.contains(market.selectedInstrument)

        return Button {
            withAnimation(Motion.spring) {
                watchlist.toggle(market.selectedInstrument)
            }
        } label: {
            Image(systemName: isSaved ? "star.fill" : "star")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isSaved ? Color(red: 0.92, green: 0.78, blue: 0.44) : .white.opacity(0.56))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSaved ? Color(red: 0.92, green: 0.78, blue: 0.44).opacity(0.13) : Color.white.opacity(0.045))
                )
        }
        .buttonStyle(.plain)
        .help(isSaved ? "Remove from watchlist" : "Add to watchlist")
        .animation(Motion.micro, value: isSaved)
    }
}

private struct InstrumentSearchControl: View {
    @ObservedObject var market: AeviumMarketViewModel
    var width: CGFloat = 180
    @FocusState private var isFocused: Bool
    @State private var highlightedResultID: InstrumentID?
    @State private var keyMonitor: Any?

    private var trimmedQuery: String {
        market.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowResults: Bool {
        isFocused && (market.isSearching || !market.searchResults.isEmpty || trimmedQuery.count >= 2 || market.errorMessage != nil)
    }

    private var visibleResults: [InstrumentMetadata] {
        Array(market.searchResults.prefix(7))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))

                TextField("Symbol", text: Binding(
                    get: { market.searchQuery },
                    set: { market.updateSearchQuery($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity)
                .focused($isFocused)
                .onSubmit {
                    commitSearchSelection()
                }

                if !trimmedQuery.isEmpty {
                    Button {
                        market.updateSearchQuery("")
                        isFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.32))
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98),
                                Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    )
            )

            if shouldShowResults {
                searchMenu
                    .offset(y: 41)
                    .zIndex(20)
                    .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: width, height: 36, alignment: .topLeading)
        .onChange(of: isFocused) { _, focused in
            if focused {
                installKeyMonitor()
                alignHighlightToResults(preferFirst: true)
            } else {
                removeKeyMonitor()
                highlightedResultID = nil
            }
        }
        .onChange(of: market.searchResults) { _, _ in
            alignHighlightToResults(preferFirst: true)
        }
        .onChange(of: market.searchQuery) { _, _ in
            alignHighlightToResults(preferFirst: false)
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .animation(Motion.spring, value: shouldShowResults)
    }

    private var searchMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            if market.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching instruments")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                }
                .frame(height: 34)
                .padding(.horizontal, 10)
            } else if !market.searchResults.isEmpty {
                ForEach(visibleResults, id: \.id) { instrument in
                    resultRow(instrument, isHighlighted: instrument.id == highlightedResultID)
                }
            } else if trimmedQuery.count >= 2 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("No matches")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text("Press Return to resolve \(trimmedQuery.uppercased()).")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.horizontal, 10)
                .frame(height: 45, alignment: .leading)
            } else if let error = market.errorMessage {
                Text(error)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.55))
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .padding(5)
        .frame(width: max(width + 66, 260), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.08, green: 0.095, blue: 0.11).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 14)
    }

    private func resultRow(_ instrument: InstrumentMetadata, isHighlighted: Bool) -> some View {
        Button {
            selectResult(instrument)
        } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(instrument.compactTitle.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(isHighlighted ? Color(red: 0.78, green: 0.92, blue: 0.86) : .white.opacity(0.88))
                    .lineLimit(1)

                    Text(instrument.name.isEmpty ? instrument.exchange : instrument.name)
                        .font(.system(size: 10.5, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(instrument.provider.uppercased())
                    .font(.system(size: 8.5, weight: .semibold, design: .default))
                    .tracking(1.0)
                    .foregroundStyle(isHighlighted ? .white.opacity(0.58) : .white.opacity(0.36))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHighlighted ? Color.white.opacity(0.075) : Color.white.opacity(0.001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHighlighted ? Color(red: 0.74, green: 0.88, blue: 0.82).opacity(0.18) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                highlightedResultID = instrument.id
            }
        }
        .animation(Motion.spring, value: isHighlighted)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isFocused else { return false }

        switch event.keyCode {
        case 125:
            moveHighlight(by: 1)
            return !visibleResults.isEmpty
        case 126:
            moveHighlight(by: -1)
            return !visibleResults.isEmpty
        case 36, 76:
            commitSearchSelection()
            return true
        case 53:
            isFocused = false
            return true
        default:
            return false
        }
    }

    private func moveHighlight(by offset: Int) {
        let results = visibleResults
        guard !results.isEmpty else { return }

        let currentIndex = highlightedResultID.flatMap { selectedID in
            results.firstIndex { $0.id == selectedID }
        }

        let nextIndex: Int
        if let currentIndex {
            nextIndex = (currentIndex + offset + results.count) % results.count
        } else {
            nextIndex = offset < 0 ? results.count - 1 : 0
        }

        highlightedResultID = results[nextIndex].id
    }

    private func commitSearchSelection() {
        if let instrument = highlightedInstrument ?? visibleResults.first {
            selectResult(instrument)
        } else {
            market.commitSearch()
            isFocused = false
        }
    }

    private func selectResult(_ instrument: InstrumentMetadata) {
        withAnimation(Motion.spring) {
            market.selectInstrument(instrument)
        }
        highlightedResultID = nil
        isFocused = false
    }

    private var highlightedInstrument: InstrumentMetadata? {
        guard let highlightedResultID else { return nil }
        return visibleResults.first { $0.id == highlightedResultID }
    }

    private func alignHighlightToResults(preferFirst: Bool) {
        let results = visibleResults
        guard !results.isEmpty else {
            highlightedResultID = nil
            return
        }

        if let highlightedResultID, results.contains(where: { $0.id == highlightedResultID }) {
            return
        }

        highlightedResultID = preferFirst ? results.first?.id : nil
    }
}

private struct SyncStatusStrip: View {
    let state: SyncState

    private var tint: Color {
        switch state.state {
        case .connected:
            return Color(red: 0.56, green: 0.84, blue: 0.72)
        case .backfilling, .connecting:
            return Color(red: 0.78, green: 0.70, blue: 0.54)
        case .rateLimited, .delayed:
            return Color(red: 0.85, green: 0.64, blue: 0.46)
        case .failed, .disconnected:
            return Color(red: 0.86, green: 0.50, blue: 0.52)
        case .idle:
            return Color.white.opacity(0.42)
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 5.5, height: 5.5)

            Text(label)
                .font(.system(size: 10.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)

            if state.state == .backfilling {
                ProgressView(value: state.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 58)
                    .tint(tint)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private var label: String {
        switch state.state {
        case .backfilling:
            return "\(state.message) \(Int(state.progress * 100))%"
        case .connecting:
            return state.message
        case .connected:
            return state.message
        case .rateLimited, .delayed, .disconnected, .failed:
            return state.message
        case .idle:
            return "Preparing feed"
        }
    }
}

private struct MarketSeriesLoadingOverlay: View {
    let symbol: String
    let state: SyncState

    private var message: String {
        switch state.state {
        case .idle:
            return "Preparing feed"
        case .connecting, .backfilling, .connected, .delayed, .rateLimited, .disconnected, .failed:
            return state.message
        }
    }

    private var tint: Color {
        switch state.state {
        case .failed, .disconnected:
            return Color(red: 0.90, green: 0.50, blue: 0.52)
        case .rateLimited, .delayed:
            return Color(red: 0.86, green: 0.66, blue: 0.46)
        default:
            return Color(red: 0.60, green: 0.82, blue: 0.74)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(tint)

            VStack(spacing: 3) {
                Text(symbol.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.82))

                Text(message)
                    .font(.system(size: 11.5, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            liquidGlassSurface(
                RoundedRectangle(cornerRadius: 8, style: .continuous),
                fallbackFill: Color(red: 0.07, green: 0.078, blue: 0.09).opacity(0.90)
            )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}

private struct AeviumRangeSelector: View {
    @Binding var selectedRange: ChartRange
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartRange.allCases) { range in
                Button {
                    withAnimation(Motion.spring) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(selectedRange == range ? .white.opacity(0.9) : .white.opacity(0.38))
                        .frame(width: 31, height: 27)
                        .background {
                            if selectedRange == range {
                                liquidGlassSurface(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous),
                                    fallbackFill: Color.white.opacity(0.105)
                                )
                                    .matchedGeometryEffect(id: "range-selection", in: selectionNamespace)
                                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }
}

private struct ForesightSelector: View {
    @Binding var selectedForesight: ForesightRange
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ForesightRange.allCases) { range in
                Button {
                    withAnimation(Motion.spring) {
                        selectedForesight = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(selectedForesight == range ? .white.opacity(0.9) : .white.opacity(0.38))
                        .frame(width: range == .off ? 34 : 36, height: 27)
                        .background {
                            if selectedForesight == range {
                                liquidGlassSurface(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous),
                                    fallbackFill: Color.white.opacity(0.105)
                                )
                                    .matchedGeometryEffect(id: "foresight-selection", in: selectionNamespace)
                                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
        .help("Foresight horizon")
    }
}

private struct IndicatorMenuButton: View {
    @Binding var selectedIndicators: Set<ForesightIndicator>
    @State private var isPopoverPresented = false
    private let columns = [
        GridItem(.flexible(minimum: 168), spacing: 10),
        GridItem(.flexible(minimum: 168), spacing: 10),
        GridItem(.flexible(minimum: 168), spacing: 10)
    ]

    private var selectedCount: Int {
        selectedIndicators.count
    }

    var body: some View {
        Button {
            withAnimation(Motion.spring) {
                isPopoverPresented.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Text("Indicators")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                Text(selectedCount > 0 ? "\(selectedCount) on" : "None")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(selectedCount > 0 ? 0.48 : 0.34))

                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(minWidth: 18, minHeight: 18)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.76, green: 0.88, blue: 0.82))
                        )
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
            }
            .padding(.horizontal, 12)
            .frame(width: 198, height: 35, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.98),
                                Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(isPopoverPresented ? 0.085 : 0.055), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            indicatorPopover
        }
        .help("Chart indicators")
    }

    private var indicatorPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Indicators")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Text(selectedCount == 0 ? "No overlays active" : "\(selectedCount) active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.44))
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    actionCapsule("All") {
                        withAnimation(Motion.spring) {
                            selectedIndicators = Set(ForesightIndicator.menuCases)
                        }
                    }

                    actionCapsule("Clear") {
                        withAnimation(Motion.spring) {
                            selectedIndicators.removeAll()
                        }
                    }
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ForesightIndicatorGroup.allCases) { group in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text(group.title)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(1.1)
                                    .foregroundStyle(.white.opacity(0.40))
                                Spacer()
                            }

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                ForEach(group.indicators) { indicator in
                                    indicatorRow(for: indicator)
                                }
                            }
                        }
                        .padding(.top, group == .allCases.first ? 0 : 2)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 610)
        .frame(maxHeight: 540)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.08, green: 0.085, blue: 0.095).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }

    private func indicatorRow(for indicator: ForesightIndicator) -> some View {
        Button {
            withAnimation(Motion.spring) {
                toggle(indicator)
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(indicator.color.opacity(selectedIndicators.contains(indicator) ? 0.34 : 0.16))
                        .frame(width: 24, height: 24)

                    Image(systemName: selectedIndicators.contains(indicator) ? "checkmark" : "plus")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(selectedIndicators.contains(indicator) ? .white.opacity(0.92) : indicator.color.opacity(0.92))
                }

                Text(indicator.menuTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: selectedIndicators.contains(indicator) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectedIndicators.contains(indicator) ? indicator.color.opacity(0.96) : .white.opacity(0.22))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                liquidGlassSurface(
                    RoundedRectangle(cornerRadius: 10, style: .continuous),
                    fallbackFill: Color.white.opacity(selectedIndicators.contains(indicator) ? 0.075 : 0.03),
                    strokeOpacity: selectedIndicators.contains(indicator) ? 0.34 : 0.06
                )
            )
        }
        .buttonStyle(.plain)
        .hoverInsight(indicator.insight, delaySeconds: 0.45)
        .animation(Motion.spring, value: selectedIndicators.contains(indicator))
    }

    private func actionCapsule(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    liquidGlassSurface(
                        Capsule(style: .continuous),
                        fallbackFill: Color.white.opacity(0.05),
                        strokeOpacity: 0.06
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ indicator: ForesightIndicator) {
        if selectedIndicators.contains(indicator) {
            selectedIndicators.remove(indicator)
        } else {
            selectedIndicators.insert(indicator)
        }
    }
}

private struct ChartResolutionControl: View {
    @Binding var chartSmoothness: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.below.rectangle")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Slider(value: $chartSmoothness, in: 0...1)
                .tint(Color(red: 0.77, green: 0.85, blue: 0.92))
                .frame(width: 120)
        }
        .padding(.horizontal, 10)
        .frame(height: 35)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
        .help("Chart smoothing from raw to super smooth")
    }
}

private struct MarketInspector: View {
    let points: [GraphPoint]
    let analytics: MarketSeriesAnalytics
    let selectedInstrument: InstrumentMetadata
    @ObservedObject var watchlist: InstrumentWatchlistStore
    let instrumentSymbol: String
    let instrumentSession: String
    let selectedRange: ChartRange
    let isUp: Bool
    @Binding var selectedPanel: InspectorPanel
    let onSelectWatchlistInstrument: (InstrumentMetadata) -> Void
    @Namespace private var panelSelectionNamespace

    private var displaySymbol: String {
        instrumentSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var marketState: String {
        instrumentSession
    }

    private var lastValue: Double { analytics.lastValue }
    private var absoluteChange: Double { analytics.absoluteChange }
    private var highValue: Double { analytics.highValue }
    private var lowValue: Double { analytics.lowValue }
    private var percentChange: Double { analytics.percentChange }
    private var pointCount: Int { analytics.pointCount }

    private var sampleCadenceMinutes: Double {
        analytics.sampleCadenceMinutes
    }

    private var windowHours: Double {
        analytics.windowHours
    }

    private var averageReturn: Double {
        analytics.averageReturn
    }

    private var medianReturn: Double {
        analytics.medianReturn
    }

    private var returnStdDev: Double {
        analytics.returnStdDev
    }

    private var realizedVolPercent: Double {
        analytics.realizedVolPercent
    }

    private var averageCandleMovePercent: Double {
        analytics.averageCandleMovePercent
    }

    private var downsideDeviationPercent: Double {
        analytics.downsideDeviationPercent
    }

    private var trendSlopePercentPerStep: Double {
        analytics.trendSlopePercentPerStep
    }

    private var efficiencyRatio: Double {
        analytics.efficiencyRatio
    }

    private var maxDrawdownPercent: Double {
        analytics.maxDrawdownPercent
    }

    private var recoveryPercentFromLow: Double {
        analytics.recoveryPercentFromLow
    }

    private var meanPrice: Double {
        analytics.meanPrice
    }

    private var medianPrice: Double {
        analytics.medianPrice
    }

    private var priceStdDev: Double {
        analytics.priceStdDev
    }

    private var zScore: Double {
        analytics.zScore
    }

    private var vwapProxy: Double {
        analytics.vwapProxy
    }

    private var percentileInRange: Double {
        analytics.percentileInRange
    }

    private var distanceToHighPercent: Double {
        analytics.distanceToHighPercent
    }

    private var distanceFromLowPercent: Double {
        analytics.distanceFromLowPercent
    }

    private var vwapDriftPercent: Double {
        guard vwapProxy != 0 else { return 0 }
        return ((lastValue - vwapProxy) / abs(vwapProxy)) * 100
    }

    private var medianDriftPercent: Double {
        guard medianPrice != 0 else { return 0 }
        return ((lastValue - medianPrice) / abs(medianPrice)) * 100
    }

    private var liquidityProxy: Double {
        let amplitude = max(volatilityPercent, 0.01)
        return Double(pointCount) / amplitude
    }

    private var trendQuality: String {
        if efficiencyRatio > 0.62 { return "Directed" }
        if efficiencyRatio > 0.38 { return "Transitional" }
        return "Choppy"
    }

    private var sortinoLike: Double {
        averageReturn / max(downsideDeviationPercent / 100, 0.0001)
    }

    private var flowScore: Double {
        (0.52 + (percentChange / 18)).clamped(to: 0.16...0.84)
    }

    private var stressScore: Double {
        (0.44 + (volatilityPercent / 18) + (isUp ? -0.05 : 0.07)).clamped(to: 0.14...0.88)
    }

    private var noiseScore: Double {
        (0.24 + (volatilityPercent / 30)).clamped(to: 0.08...0.64)
    }

    private var confidenceScore: Double {
        (0.62 - noiseScore * 0.35 + (isUp ? 0.06 : -0.08)).clamped(to: 0.18...0.86)
    }

    private var buyShare: Double {
        (0.50 + (flowScore - 0.5) * 0.9 + (isUp ? 0.03 : -0.03)).clamped(to: 0.18...0.82)
    }

    private var sellShare: Double { 1 - buyShare }

    private var notionalVolume: Double {
        let spreadEnergy = abs(highValue - lowValue) + abs(absoluteChange) + 1.4
        return Double(pointCount) * spreadEnergy * 1350
    }

    private var buyVolume: Double { notionalVolume * buyShare }
    private var sellVolume: Double { notionalVolume * sellShare }
    private var volumeDelta: Double { buyVolume - sellVolume }
    private var imbalancePercent: Double { (buyShare - sellShare) * 100 }
    private var pressureScore: Double { ((buyShare - 0.5) * 2 + (isUp ? 0.22 : -0.22)).clamped(to: -1...1) }

    private var var95Percent: Double { returnStdDev * 1.65 * 100 }
    private var cvar95Percent: Double { returnStdDev * 2.10 * 100 }

    private var pulseSeries: [Double] {
        (0..<48).map { i in
            let t = Double(i) / 47
            let wave = 0.30 * sin(t * .pi * 3.2) + 0.22 * cos(t * .pi * 5.4)
            let bias = (buyShare - 0.5) * 0.85
            return 0.5 + wave + bias
        }
    }

    private var depthSeries: [Double] {
        (0..<10).map { i in
            let t = Double(i) / 9
            let wave = 0.24 * cos(t * .pi * 2.3) + 0.16 * sin(t * .pi * 4.8)
            return (0.50 + wave + (buyShare - 0.5) * 0.55).clamped(to: 0.10...0.90)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                instrumentHeroCard
                panelSelector
                VStack(alignment: .leading, spacing: 10) {
                    selectedPanelContent
                }
                .id(selectedPanel)
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.985)))
            }
            .padding(.top, 22)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.065, green: 0.070, blue: 0.082),
                    Color(red: 0.055, green: 0.058, blue: 0.068)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var instrumentHeroCard: some View {
        card(tint: isUp ? Color(red: 0.16, green: 0.36, blue: 0.30) : Color(red: 0.36, green: 0.20, blue: 0.23)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(displaySymbol)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.92))

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.48, green: 0.85, blue: 0.69))
                                .frame(width: 6, height: 6)
                            Text(marketState)
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.56))
                        }
                    }

                    if pointCount > 1 {
                        Text(lastValue, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 35, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.96))
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.18), value: lastValue)
                            .hoverInsight(
                                InspectorInsight(
                                    title: "Last Price",
                                    meaning: "Most recent traded price for the current symbol.",
                                    expectedRange: "\(number(lowValue)) to \(number(highValue)) for this selected window.",
                                    action: "If price repeatedly closes outside this band, reassess trend strength and widen risk limits."
                                )
                            )

                        Text(signedPercentText)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(isUp ? Color(red: 0.60, green: 0.82, blue: 0.72) : Color(red: 0.88, green: 0.58, blue: 0.58))
                    } else {
                        Text("Loading")
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.82))

                        Text("Waiting for market data")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }

                Spacer(minLength: 10)

                if pointCount > 1 {
                    VolumeBalanceRing(
                        buyShare: buyShare,
                        buyColor: Color(red: 0.56, green: 0.84, blue: 0.72),
                        sellColor: Color(red: 0.86, green: 0.56, blue: 0.56)
                    )
                    .frame(width: 60, height: 60)
                    .hoverInsight(
                        InspectorInsight(
                            title: "Buy vs Sell Dominance",
                            meaning: "Shows the directional split of participation between aggressive buyers and sellers.",
                            expectedRange: "Healthy two-way markets often sit near 45/55 to 55/45.",
                            action: "If skew exceeds 65/35 for sustained periods, expect trend continuation or sharp mean-reversion."
                        )
                    )
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 60, height: 60)
                        .tint(Color(red: 0.60, green: 0.82, blue: 0.74))
                }
            }

            if pointCount > 1 {
                VStack(spacing: 9) {
                    HStack {
                        volumeBadge("Buy", value: buyVolume, color: Color(red: 0.56, green: 0.84, blue: 0.72))
                        Spacer()
                        volumeBadge("Sell", value: sellVolume, color: Color(red: 0.86, green: 0.56, blue: 0.56))
                    }

                    splitVolumeBar(buyShare: buyShare, sellShare: sellShare)
                        .hoverInsight(
                            InspectorInsight(
                                title: "Volume Split",
                                meaning: "Relative participation by side within the active observation window.",
                                expectedRange: "Balanced markets cluster around 50/50; strong directional sessions can stretch to 70/30.",
                                action: "Outside 70/30, tighten stops and validate with volatility before chasing momentum."
                            )
                        )
                }
            } else {
                Divider()
                    .overlay(Color.white.opacity(0.08))

                Text("The chart will update when the first cached or live samples arrive.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var panelSelector: some View {
        HStack(spacing: 4) {
            ForEach(InspectorPanel.allCases) { panel in
                Button {
                    withAnimation(Motion.spring) {
                        selectedPanel = panel
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(panel.rawValue)
                        .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(selectedPanel == panel ? .white.opacity(0.88) : .white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background {
                        if selectedPanel == panel {
                            liquidGlassSurface(
                                RoundedRectangle(cornerRadius: 7, style: .continuous),
                                fallbackFill: Color.white.opacity(0.09)
                            )
                                .matchedGeometryEffect(id: "panel-selection", in: panelSelectionNamespace)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var selectedPanelContent: some View {
        if pointCount < 2 {
            loadingInspectorCard
            watchlistCard
        } else {
            switch selectedPanel {
            case .summary:
                snapshotCard
                modelSignalsCard
                watchlistCard
            case .flow:
                orderFlowCard
                priceStructureCard
            case .risk:
                momentumTrendCard
                riskMapCard
            }
        }
    }

    private var loadingInspectorCard: some View {
        card(tint: Color(red: 0.13, green: 0.18, blue: 0.22)) {
            sectionHeader("SYNC")

            VStack(alignment: .leading, spacing: 6) {
                Text("Loading \(displaySymbol)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text("Cleared the previous instrument and waiting for fresh samples.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var snapshotCard: some View {
        card(tint: Color(red: 0.15, green: 0.19, blue: 0.20)) {
            sectionHeader("MARKET SNAPSHOT")

            gridMetrics([
                ("Change", signedAbsoluteText),
                ("Change %", signedPercentText),
                ("High", number(highValue)),
                ("Low", number(lowValue)),
                ("Median", number(medianPrice)),
                ("VWAP*", number(vwapProxy)),
                ("Z-Score", signedNumber(zScore)),
                ("Window", "\(windowHours.formatted(.number.precision(.fractionLength(1))))h")
            ])

            structureBar(
                label: "Range Position",
                leftCaption: "Low \(distanceFromLowPercent.formatted(.number.precision(.fractionLength(0))))%",
                rightCaption: "High \(distanceToHighPercent.formatted(.number.precision(.fractionLength(0))))%",
                value: percentileInRange
            )
        }
    }

    private var orderFlowCard: some View {
        card(tint: Color(red: 0.13, green: 0.20, blue: 0.28)) {
            sectionHeader("BUYING VS SELLING")

            HStack(alignment: .firstTextBaseline) {
                Text("Buy/Sell Pressure")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                Spacer()
                Text("\(imbalancePercent >= 0 ? "+" : "")\(imbalancePercent.formatted(.number.precision(.fractionLength(1))))%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(imbalancePercent >= 0 ? Color(red: 0.58, green: 0.84, blue: 0.73) : Color(red: 0.88, green: 0.58, blue: 0.58))
                    .monospacedDigit()
            }
            .hoverInsight(
                InspectorInsight(
                    title: "Buy/Sell Pressure",
                    meaning: "Net directional pressure from buying versus selling activity.",
                    expectedRange: "Normal rotational regimes often stay within -12% to +12%.",
                    action: "If imbalance persists above +/-20%, favor trend setups until momentum deteriorates."
                )
            )

            SparklineArea(data: pulseSeries, color: Color(red: 0.64, green: 0.86, blue: 0.78))
                .frame(height: 44)
                .hoverInsight(
                    InspectorInsight(
                        title: "Trading Activity",
                        meaning: "Short-horizon shape of demand/supply acceleration.",
                        expectedRange: "Smooth undulations indicate stable participation; abrupt spikes imply event-driven activity.",
                        action: "When pulses become erratic, reduce sizing and wait for confirmation candles."
                    )
                )

            VStack(spacing: 8) {
                ForEach(Array(depthSeries.enumerated()), id: \.offset) { index, value in
                    depthRow(
                        label: "L\(index + 1)",
                        bid: value,
                        ask: (1 - value).clamped(to: 0.08...0.92)
                    )
                }
            }
        }
    }

    private var priceStructureCard: some View {
        card(tint: Color(red: 0.16, green: 0.14, blue: 0.24)) {
            sectionHeader("PRICE STRUCTURE")

            priceStructureTrack()
                .frame(height: 56)
                .hoverInsight(
                    InspectorInsight(
                        title: "Price Structure Track",
                        meaning: "Shows current price, VWAP proxy, and median position inside the active high-low range.",
                        expectedRange: "In balanced markets, last price often rotates around VWAP/median instead of hugging extremes.",
                        action: "If last price pins at an edge while VWAP lags, favor continuation. If it snaps back to VWAP, fade extension."
                    )
                )

            HStack(spacing: 8) {
                structureChip("Range", number(highValue - lowValue), tone: Color(red: 0.70, green: 0.80, blue: 0.93))
                structureChip("VWAP Drift", signedPercent(vwapDriftPercent), tone: vwapDriftPercent >= 0 ? Color(red: 0.58, green: 0.84, blue: 0.74) : Color(red: 0.86, green: 0.60, blue: 0.60))
                structureChip("Z-Score", signedNumber(zScore), tone: abs(zScore) < 1.5 ? Color(red: 0.69, green: 0.78, blue: 0.93) : Color(red: 0.87, green: 0.67, blue: 0.57))
            }

            structureBar(
                label: "Range Position",
                leftCaption: "Low \(distanceFromLowPercent.formatted(.number.precision(.fractionLength(0))))%",
                rightCaption: "High \(distanceToHighPercent.formatted(.number.precision(.fractionLength(0))))%",
                value: percentileInRange
            )
            .hoverInsight(
                InspectorInsight(
                    title: "Range Position",
                    meaning: "Relative location of price between window low and high.",
                    expectedRange: "Middle zone 35-65% usually indicates rotational behavior.",
                    action: "Persistent >80% or <20% suggests directional pressure; switch from mean-reversion to trend tactics."
                )
            )

            structureBar(
                label: "Mean Reversion Gap",
                leftCaption: "Median \(signedPercent(medianDriftPercent))",
                rightCaption: "VWAP \(signedPercent(vwapDriftPercent))",
                value: ((vwapDriftPercent + 8) / 16).clamped(to: 0...1)
            )
            .hoverInsight(
                InspectorInsight(
                    title: "Reversion Gap",
                    meaning: "Distance between current price and central anchors (median and VWAP).",
                    expectedRange: "Small gaps indicate equilibrium; large sustained gaps imply directional expansion.",
                    action: "If both drifts widen with strong participation, favor continuation. If participation weakens, prepare for snapback."
                )
            )
        }
    }

    private var modelSignalsCard: some View {
        card(tint: Color(red: 0.14, green: 0.22, blue: 0.20)) {
            sectionHeader("MODEL SIGNALS")
            signalBar("Participation", value: flowScore, color: Color(red: 0.54, green: 0.78, blue: 0.68))
                .hoverInsight(
                    InspectorInsight(
                        title: "Participation Score",
                        meaning: "Directional participation intensity after normalization.",
                        expectedRange: "Typical neutral range: 40 to 60.",
                        action: "Above 65 supports continuation. Below 35 favors defensive or mean-reversion posture."
                    )
                )
            signalBar("Stress", value: stressScore, color: Color(red: 0.78, green: 0.60, blue: 0.48))
                .hoverInsight(
                    InspectorInsight(
                        title: "Stress Score",
                        meaning: "Compression between volatility and directional conviction.",
                        expectedRange: "Most stable regimes hold below 55.",
                        action: "Above 70, reduce leverage and widen slippage assumptions."
                    )
                )
            signalBar("Noise", value: noiseScore, color: Color(red: 0.56, green: 0.66, blue: 0.78))
                .hoverInsight(
                    InspectorInsight(
                        title: "Noise Score",
                        meaning: "Choppiness ratio of movement that does not contribute to net trend.",
                        expectedRange: "Efficient trends often remain under 40.",
                        action: "Above 55, avoid breakout entries unless confirmed by volume expansion."
                    )
                )
            signalBar("Confidence", value: confidenceScore, color: Color(red: 0.68, green: 0.76, blue: 0.94))
                .hoverInsight(
                    InspectorInsight(
                        title: "Confidence Score",
                        meaning: "Composite certainty from participation quality, volatility and noise.",
                        expectedRange: "Actionable zone is usually above 55.",
                        action: "Below 45, prefer smaller position sizes and wait for structure confirmation."
                    )
                )
        }
    }

    private var momentumTrendCard: some View {
        card(tint: Color(red: 0.13, green: 0.18, blue: 0.27)) {
            sectionHeader("MOMENTUM & TREND")
            gridMetrics([
                ("Mean Ret", signedPercent(averageReturn * 100)),
                ("Median Ret", signedPercent(medianReturn * 100)),
                ("Ret Vol", "\(realizedVolPercent.formatted(.number.precision(.fractionLength(2))))%"),
                ("Down Dev", "\(downsideDeviationPercent.formatted(.number.precision(.fractionLength(2))))%"),
                ("Avg Move", "\(averageCandleMovePercent.formatted(.number.precision(.fractionLength(2))))%"),
                ("Slope", signedPercent(trendSlopePercentPerStep)),
                ("Efficiency", "\(Int(efficiencyRatio * 100))"),
                ("Trend", trendQuality),
                ("Drawdown", "\(maxDrawdownPercent.formatted(.number.precision(.fractionLength(2))))%"),
                ("Recovery", "\(recoveryPercentFromLow.formatted(.number.precision(.fractionLength(2))))%"),
                ("Sortino*", signedNumber(sortinoLike))
            ])
        }
    }

    private var riskMapCard: some View {
        card(tint: Color(red: 0.22, green: 0.16, blue: 0.18)) {
            sectionHeader("RISK MAP")
            gridMetrics([
                ("Bias", isUp ? "Bullish Drift" : "Risk-off"),
                ("Regime", volatilityPercent > 4.5 ? "Elevated" : "Stable"),
                ("Pressure", "\(Int(abs(pressureScore) * 100))"),
                ("Imbalance", signedPercent(imbalancePercent)),
                ("Net Vol", compactVolume(volumeDelta)),
                ("State", marketState),
                ("Timeframe", selectedRange.rawValue),
                ("Window", "\(windowHours.formatted(.number.precision(.fractionLength(1))))h"),
                ("Cadence", "\(sampleCadenceMinutes.formatted(.number.precision(.fractionLength(1))))m"),
                ("Liquidity", Int(liquidityProxy).formatted()),
                ("Sharpe*", signedNumber(averageReturn / max(returnStdDev, 0.0001))),
                ("VaR 95*", "\(var95Percent.formatted(.number.precision(.fractionLength(2))))%"),
                ("CVaR 95*", "\(cvar95Percent.formatted(.number.precision(.fractionLength(2))))%")
            ])
        }
    }

    private var watchlistCard: some View {
        card(tint: Color(red: 0.24, green: 0.22, blue: 0.14)) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("WATCHLIST")
                Spacer()
                Text("\(watchlist.instruments.count)")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
            }

            if watchlist.instruments.isEmpty {
                Text("No saved symbols")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(watchlist.instruments.prefix(8), id: \.id) { instrument in
                        watchlistRow(instrument)
                    }
                }
            }
        }
    }

    private func watchlistRow(_ instrument: InstrumentMetadata) -> some View {
        let isSelected = instrument.id == selectedInstrument.id

        return HStack(spacing: 6) {
            Button {
                onSelectWatchlistInstrument(instrument)
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSelected ? Color(red: 0.92, green: 0.78, blue: 0.44) : Color.white.opacity(0.16))
                        .frame(width: 6, height: 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(compactWatchlistSymbol(instrument))
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)

                        Text(watchlistSubtitle(instrument))
                            .font(.system(size: 9.5, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.38))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                watchlist.remove(id: instrument.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.045))
                    )
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.085) : Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color(red: 0.92, green: 0.78, blue: 0.44).opacity(0.24) : Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }

    private func compactWatchlistSymbol(_ instrument: InstrumentMetadata) -> String {
        instrument.compactTitle
            .replacingOccurrences(of: " / ", with: "/")
            .uppercased()
    }

    private func watchlistSubtitle(_ instrument: InstrumentMetadata) -> String {
        if !instrument.name.isEmpty {
            return instrument.name
        }

        return instrument.exchange.isEmpty ? instrument.provider.uppercased() : instrument.exchange
    }

    private var signedAbsoluteText: String {
        "\(absoluteChange >= 0 ? "+" : "")\(number(absoluteChange))"
    }

    private var signedPercentText: String {
        "\(percentChange >= 0 ? "+" : "")\(percentChange.formatted(.number.precision(.fractionLength(2))))%"
    }

    private var volatilityPercent: Double {
        analytics.volatilityPercent
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func signedNumber(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "")\(value.formatted(.number.precision(.fractionLength(2))))"
    }

    private func signedPercent(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "")\(value.formatted(.number.precision(.fractionLength(2))))%"
    }

    private func compactVolume(_ value: Double) -> String {
        let absolute = abs(value)
        let sign = value >= 0 ? "+" : "-"
        if absolute >= 1_000_000_000 {
            return "\(sign)\((absolute / 1_000_000_000).formatted(.number.precision(.fractionLength(2))))B"
        }
        if absolute >= 1_000_000 {
            return "\(sign)\((absolute / 1_000_000).formatted(.number.precision(.fractionLength(2))))M"
        }
        if absolute >= 1_000 {
            return "\(sign)\((absolute / 1_000).formatted(.number.precision(.fractionLength(1))))K"
        }
        return "\(sign)\(Int(absolute))"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(1.8)
            .foregroundStyle(.white.opacity(0.36))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.52))
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private func signalBar(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.62))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(color.opacity(0.80))
                        .frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 5)
        }
    }

    private func splitVolumeBar(buyShare: Double, sellShare: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 0) {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.56, green: 0.84, blue: 0.72).opacity(0.82))
                    .frame(width: width * buyShare)
                Capsule(style: .continuous)
                    .fill(Color(red: 0.86, green: 0.56, blue: 0.56).opacity(0.82))
                    .frame(width: width * sellShare)
            }
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .frame(height: 7)
    }

    private func volumeBadge(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(color.opacity(0.95))
            Text(compactVolume(value))
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func depthRow(label: String, bid: Double, ask: Double) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 20, alignment: .leading)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.06))

                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Color(red: 0.56, green: 0.84, blue: 0.72).opacity(0.72))
                            .frame(width: width * bid)
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(Color(red: 0.86, green: 0.56, blue: 0.56).opacity(0.72))
                            .frame(width: width * ask)
                    }
                }
            }
            .frame(height: 4)
        }
    }

    private func gridMetrics(_ pairs: [(String, String)]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(stride(from: 0, to: pairs.count, by: 2)), id: \.self) { idx in
                HStack(spacing: 10) {
                    metricTile(label: pairs[idx].0, value: pairs[idx].1)
                    if idx + 1 < pairs.count {
                        metricTile(label: pairs[idx + 1].0, value: pairs[idx + 1].1)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricTile(label: String, value: String) -> some View {
        let tile = VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.36))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )

        if let insight = insightForMetric(label: label, value: value) {
            tile.hoverInsight(insight)
        } else {
            tile
        }
    }

    private func priceStructureTrack() -> some View {
        GeometryReader { proxy in
            let span = max(highValue - lowValue, 0.0001)
            let lastPosition = ((lastValue - lowValue) / span).clamped(to: 0...1)
            let vwapPosition = ((vwapProxy - lowValue) / span).clamped(to: 0...1)
            let medianPosition = ((medianPrice - lowValue) / span).clamped(to: 0...1)
            let usableWidth = max(proxy.size.width - 12, 1)

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.56, green: 0.82, blue: 0.74).opacity(0.52),
                                    Color(red: 0.86, green: 0.62, blue: 0.62).opacity(0.52)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: usableWidth * lastPosition, height: 8)

                    markerDot(position: vwapPosition, color: Color(red: 0.76, green: 0.86, blue: 0.94), width: usableWidth)
                    markerDot(position: medianPosition, color: Color(red: 0.93, green: 0.80, blue: 0.62), width: usableWidth)
                    markerDot(position: lastPosition, color: .white.opacity(0.95), width: usableWidth, radius: 4.5)
                }
                .padding(.horizontal, 6)

                HStack(spacing: 10) {
                    structureLegend(name: "Low", value: number(lowValue), tone: .white.opacity(0.55))
                    structureLegend(name: "Median", value: number(medianPrice), tone: Color(red: 0.93, green: 0.80, blue: 0.62))
                    structureLegend(name: "VWAP*", value: number(vwapProxy), tone: Color(red: 0.76, green: 0.86, blue: 0.94))
                    structureLegend(name: "High", value: number(highValue), tone: .white.opacity(0.55))
                }
            }
        }
    }

    private func markerDot(position: Double, color: Color, width: CGFloat, radius: CGFloat = 3.5) -> some View {
        Circle()
            .fill(color)
            .frame(width: radius * 2, height: radius * 2)
            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
            .offset(x: (width * position) - radius)
    }

    private func structureLegend(name: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(tone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func structureChip(_ label: String, _ value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(tone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func structureBar(label: String, leftCaption: String, rightCaption: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.62, green: 0.84, blue: 0.77).opacity(0.78),
                                    Color(red: 0.82, green: 0.65, blue: 0.68).opacity(0.70)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * value.clamped(to: 0...1))
                }
            }
            .frame(height: 6)

            HStack {
                Text(leftCaption)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                Spacer()
                Text(rightCaption)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
    }

    private func card<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.095, green: 0.102, blue: 0.118).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(tint.opacity(0.62))
                        .frame(height: 2)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 8,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 8,
                                style: .continuous
                            )
                        )
                }
        )
    }

    private func insightForMetric(label: String, value: String) -> InspectorInsight? {
        switch label {
        case "Last":
            return InspectorInsight(
                title: "Last Price",
                meaning: "Latest traded value for the active symbol in this timeframe.",
                expectedRange: "\(number(lowValue)) to \(number(highValue)) inside this window.",
                action: "If price sustains beyond this range, treat it as a regime shift and re-anchor levels."
            )
        case "Change", "Change %":
            return InspectorInsight(
                title: "Session Change",
                meaning: "Net movement from window start to current price.",
                expectedRange: "Most sessions rotate inside +/-2% to +/-4% depending on asset beta.",
                action: "Above the normal band, confirm with volume and reduce mean-reversion bias."
            )
        case "Vol", "Ret Vol", "Down Dev":
            return InspectorInsight(
                title: "Volatility",
                meaning: "Magnitude and dispersion of returns in the current sample.",
                expectedRange: "Low-vol regimes typically stay compressed while high-vol regimes expand rapidly.",
                action: "When vol spikes, lower leverage and widen execution tolerance."
            )
        case "Participation", "Buy/Sell Pressure", "Pressure":
            return InspectorInsight(
                title: "Order Pressure",
                meaning: "Directional participation and dominance between buy and sell activity.",
                expectedRange: "Balanced activity usually lives near neutral; persistent extremes imply one-way pressure.",
                action: "Use sustained extremes for continuation setups, fading only after momentum decay."
            )
        case "VaR 95*", "CVaR 95*":
            return InspectorInsight(
                title: "Tail Risk Proxy",
                meaning: "Estimated downside move at high-confidence loss scenarios.",
                expectedRange: "Lower is generally safer; expansion indicates stress and wider expected tails.",
                action: "If tail-risk climbs quickly, reduce position size and shorten hold horizon."
            )
        case "Z-Score":
            return InspectorInsight(
                title: "Standardized Distance",
                meaning: "How far price is from its local mean measured in standard deviations.",
                expectedRange: "Most observations remain within -2 to +2.",
                action: "Outside +/-2, prepare for either continuation breakout or snapback depending on participation."
            )
        case "Liquidity":
            return InspectorInsight(
                title: "Liquidity Proxy",
                meaning: "Approximate tradability combining sample density and spread/volatility energy.",
                expectedRange: "Higher values imply cleaner fills and lower slippage risk.",
                action: "When liquidity proxy drops, avoid large market orders and stagger entries."
            )
        default:
            return InspectorInsight(
                title: label,
                meaning: "Context metric for \(displaySymbol) over the selected \(selectedRange.rawValue) window.",
                expectedRange: "Ranges are asset-dependent and should be interpreted against recent rolling history.",
                action: "If this value diverges sharply from recent norms, review risk and execution assumptions."
            )
        }
    }
}

private struct VolumeBalanceRing: View {
    let buyShare: Double
    let buyColor: Color
    let sellColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)

            Circle()
                .trim(from: 0, to: buyShare)
                .stroke(
                    buyColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: buyShare, to: 1)
                .stroke(
                    sellColor.opacity(0.85),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(Int(buyShare * 100))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}

private struct SparklineArea: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    for point in points {
                        path.addLine(to: point)
                    }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.26),
                            color.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let span = max(maxValue - minValue, 0.0001)

        return data.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(data.count - 1) * size.width
            let norm = (value - minValue) / span
            let y = size.height - CGFloat(norm) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}

private struct InspectorInsight {
    let title: String
    let meaning: String
    let expectedRange: String
    let action: String
}

private struct HoverInsightModifier: ViewModifier {
    let insight: InspectorInsight
    var delaySeconds: Double = 1.2

    @State private var isHovering = false
    @State private var isPresented = false
    @State private var revealTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering

                if hovering {
                    revealTask?.cancel()
                    revealTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                        if !Task.isCancelled && isHovering {
                            withAnimation(Motion.micro) {
                                isPresented = true
                            }
                        }
                    }
                } else {
                    revealTask?.cancel()
                    revealTask = nil
                    withAnimation(Motion.micro) {
                        isPresented = false
                    }
                }
            }
            .popover(isPresented: $isPresented, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))

                    insightRow("Meaning", insight.meaning)
                    insightRow("Expected", insight.expectedRange)
                    insightRow("Action", insight.action)
                }
                .padding(12)
                .frame(width: 300, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                )
            }
            .onDisappear {
                revealTask?.cancel()
                revealTask = nil
            }
    }

    @ViewBuilder
    private func insightRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.44))
            Text(detail)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension View {
    func hoverInsight(_ insight: InspectorInsight, delaySeconds: Double = 1.2) -> some View {
        modifier(HoverInsightModifier(insight: insight, delaySeconds: delaySeconds))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
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
    case twentyFiveMinutes = "25m"
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"

    var id: String { rawValue }

    init(marketTimeRange: MarketTimeRange) {
        switch marketTimeRange {
        case .twentyFiveMinutes:
            self = .twentyFiveMinutes
        case .hour:
            self = .hour
        case .day:
            self = .day
        case .week:
            self = .week
        case .month:
            self = .month
        case .quarter:
            self = .quarter
        case .year:
            self = .year
        }
    }

    var points: Int {
        switch self {
        case .twentyFiveMinutes: return 260
        case .hour: return 220
        case .day: return 260
        case .week: return 360
        case .month: return 440
        case .quarter: return 560
        case .year: return 720
        }
    }

    func slice(from data: [GraphPoint]) -> [GraphPoint] {
        Array(data.suffix(min(points, data.count)))
    }

    var marketTimeRange: MarketTimeRange {
        switch self {
        case .twentyFiveMinutes: return .twentyFiveMinutes
        case .hour: return .hour
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .quarter: return .quarter
        case .year: return .year
        }
    }
}

private enum ForesightRange: String, CaseIterable, Identifiable, Equatable {
    case off = "Off"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case hour = "1H"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .off:
            return 0
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .hour:
            return 60 * 60
        }
    }
}

private enum ForesightIndicator: String, Identifiable, Hashable {
    case sma10 = "SMA 10"
    case sma20 = "SMA 20"
    case sma50 = "SMA 50"
    case sma100 = "SMA 100"
    case sma200 = "SMA 200"
    case ema9 = "EMA 9"
    case ema12 = "EMA 12"
    case ema20 = "EMA 20"
    case ema26 = "EMA 26"
    case ema50 = "EMA 50"
    case ema100 = "EMA 100"
    case ema200 = "EMA 200"
    case wma20 = "WMA 20"
    case hma21 = "HMA 21"
    case vwap = "VWAP"
    case previousClose = "Previous Close"
    case bollingerBands = "Bollinger 20"
    case bollingerBands50 = "Bollinger 50"
    case donchianChannel = "Donchian 20"
    case donchian55 = "Donchian 55"
    case keltnerChannel = "Keltner 20"
    case atrBands = "ATR Bands"
    case regressionChannel = "Regression Channel"
    case trendDrift = "Trend Drift"
    case meanReversion = "Mean Reversion"
    case vwapCarry = "VWAP Carry"
    case volatilityCone = "Volatility Cone"
    case bollingerMid = "Bollinger Mid"
    case bollingerUpper = "Bollinger Upper"
    case bollingerLower = "Bollinger Lower"
    case bollinger50Mid = "Bollinger 50 Mid"
    case bollinger50Upper = "Bollinger 50 Upper"
    case bollinger50Lower = "Bollinger 50 Lower"
    case donchianUpper = "Donchian Upper"
    case donchianLower = "Donchian Lower"
    case donchian55Upper = "Donchian 55 Upper"
    case donchian55Lower = "Donchian 55 Lower"
    case keltnerMid = "Keltner Mid"
    case keltnerUpper = "Keltner Upper"
    case keltnerLower = "Keltner Lower"
    case atrUpper = "ATR Upper"
    case atrLower = "ATR Lower"
    case regressionMid = "Regression Mid"
    case regressionUpper = "Regression Upper"
    case regressionLower = "Regression Lower"
    case volatilityConeMid = "Volatility Cone Mid"
    case volatilityConeUpper = "Volatility Cone Upper"
    case volatilityConeLower = "Volatility Cone Lower"

    var id: String { rawValue }

    static let menuCases: [ForesightIndicator] = [
        .sma10,
        .sma20,
        .sma50,
        .sma100,
        .sma200,
        .ema9,
        .ema12,
        .ema20,
        .ema26,
        .ema50,
        .ema100,
        .ema200,
        .wma20,
        .hma21,
        .vwap,
        .previousClose,
        .bollingerBands,
        .bollingerBands50,
        .donchianChannel,
        .donchian55,
        .keltnerChannel,
        .atrBands,
        .regressionChannel,
        .trendDrift,
        .meanReversion,
        .vwapCarry,
        .volatilityCone
    ]

    var menuTitle: String {
        switch self {
        case .sma10, .sma20, .sma50, .sma100, .sma200,
             .ema9, .ema12, .ema20, .ema26, .ema50, .ema100, .ema200,
             .wma20, .hma21, .vwap, .previousClose, .bollingerBands, .bollingerBands50,
             .donchianChannel, .donchian55, .keltnerChannel, .atrBands, .regressionChannel,
             .trendDrift, .meanReversion, .vwapCarry, .volatilityCone:
            return rawValue
        case .bollingerMid, .bollingerUpper, .bollingerLower,
             .bollinger50Mid, .bollinger50Upper, .bollinger50Lower,
             .donchianUpper, .donchianLower, .donchian55Upper, .donchian55Lower,
             .keltnerMid, .keltnerUpper, .keltnerLower,
             .atrUpper, .atrLower, .regressionMid, .regressionUpper, .regressionLower,
             .volatilityConeMid, .volatilityConeUpper, .volatilityConeLower:
            return "Hidden"
        }
    }

    var tooltipTitle: String {
        switch self {
        case .bollingerMid:
            return "Bollinger Mid"
        case .bollingerUpper:
            return "Bollinger Upper"
        case .bollingerLower:
            return "Bollinger Lower"
        case .bollinger50Mid:
            return "Bollinger 50 Mid"
        case .bollinger50Upper:
            return "Bollinger 50 Upper"
        case .bollinger50Lower:
            return "Bollinger 50 Lower"
        case .donchianUpper:
            return "Donchian Upper"
        case .donchianLower:
            return "Donchian Lower"
        case .donchian55Upper:
            return "Donchian 55 Upper"
        case .donchian55Lower:
            return "Donchian 55 Lower"
        case .keltnerMid:
            return "Keltner Mid"
        case .keltnerUpper:
            return "Keltner Upper"
        case .keltnerLower:
            return "Keltner Lower"
        case .atrUpper:
            return "ATR Upper"
        case .atrLower:
            return "ATR Lower"
        case .regressionMid:
            return "Regression Mid"
        case .regressionUpper:
            return "Regression Upper"
        case .regressionLower:
            return "Regression Lower"
        case .volatilityConeMid:
            return "Volatility Cone Mid"
        case .volatilityConeUpper:
            return "Volatility Cone Upper"
        case .volatilityConeLower:
            return "Volatility Cone Lower"
        default:
            return rawValue
        }
    }

    var insight: InspectorInsight {
        switch self {
        case .sma10, .sma20, .sma50, .sma100, .sma200:
            return InspectorInsight(
                title: rawValue,
                meaning: "Simple moving average of the last \(periodLabel) closes. Smooths price and highlights trend direction.",
                expectedRange: "Best for tracking trend bias, support or resistance drift, and crossovers.",
                action: "Use shorter SMAs for pace, longer SMAs for structure. Price above it usually means trend is holding."
            )
        case .ema9, .ema12, .ema20, .ema26, .ema50, .ema100, .ema200:
            return InspectorInsight(
                title: rawValue,
                meaning: "Exponential moving average that reacts faster to recent price changes than a simple average.",
                expectedRange: "Useful for momentum turns, pullback tracking, and faster crossover reads.",
                action: "Use fast EMAs to catch turns early and slower EMAs to confirm the broader move."
            )
        case .wma20:
            return InspectorInsight(
                title: rawValue,
                meaning: "Weighted moving average that gives more importance to the most recent samples.",
                expectedRange: "Sits between SMA and EMA in responsiveness.",
                action: "Watch it when you want a cleaner trend line without the extra snap of a fast EMA."
            )
        case .hma21:
            return InspectorInsight(
                title: rawValue,
                meaning: "Hull moving average designed to reduce lag while keeping the line smooth.",
                expectedRange: "Often turns earlier than standard moving averages in strong swings.",
                action: "Use it for cleaner trend shifts, but confirm with price because it can still whip in chop."
            )
        case .vwap:
            return InspectorInsight(
                title: rawValue,
                meaning: "Volume-weighted average price for the current session or visible run.",
                expectedRange: "Common benchmark for fair value and intraday positioning.",
                action: "Price above VWAP usually means buyers control the session; below it suggests weaker tone."
            )
        case .previousClose:
            return InspectorInsight(
                title: rawValue,
                meaning: "Flat reference line marking the previous closing price.",
                expectedRange: "Acts as a simple context anchor for gaps, reclaims, and rejection levels.",
                action: "Treat it like a headline level. Reclaiming it can change the session tone fast."
            )
        case .bollingerBands:
            return InspectorInsight(
                title: rawValue,
                meaning: "20-period moving average with volatility bands two standard deviations above and below.",
                expectedRange: "Band width expands in volatility and tightens during compression.",
                action: "Use squeezes for breakout prep and band tags for extension context, not automatic reversals."
            )
        case .bollingerBands50:
            return InspectorInsight(
                title: rawValue,
                meaning: "Slower Bollinger structure with a 50-period base, better for broader moves.",
                expectedRange: "Less reactive than the 20-period version and better for higher-level structure.",
                action: "Use it when the fast bands are too noisy and you want a calmer envelope."
            )
        case .donchianChannel:
            return InspectorInsight(
                title: rawValue,
                meaning: "Highest high and lowest low over the last 20 samples.",
                expectedRange: "Shows breakout boundaries and short-term range containment.",
                action: "A break above the upper line or below the lower line often marks a regime change."
            )
        case .donchian55:
            return InspectorInsight(
                title: rawValue,
                meaning: "Broader Donchian breakout envelope based on the last 55 samples.",
                expectedRange: "Slower channel used for larger structure and trend confirmation.",
                action: "Use it when you care more about durable breaks than quick noise."
            )
        case .keltnerChannel:
            return InspectorInsight(
                title: rawValue,
                meaning: "EMA centerline with ATR-based outer bands that adapt to movement size.",
                expectedRange: "Cleaner than Bollinger in trend environments because it follows range expansion directly.",
                action: "Watch for price walking the outer band when trend strength is real."
            )
        case .atrBands:
            return InspectorInsight(
                title: rawValue,
                meaning: "Range bands around price using average true movement rather than standard deviation.",
                expectedRange: "Helpful for framing typical travel distance and expansion risk.",
                action: "Use it to judge whether the move is still normal or already stretched."
            )
        case .regressionChannel:
            return InspectorInsight(
                title: rawValue,
                meaning: "Trend line fitted through recent price with upper and lower deviation rails.",
                expectedRange: "Shows slope, fair trend path, and distance from that path.",
                action: "Price holding the channel supports continuation. Sharp deviations hint at mean reversion risk."
            )
        case .trendDrift:
            return InspectorInsight(
                title: rawValue,
                meaning: "Projects the recent slope forward into the foresight lane using the current trend pace.",
                expectedRange: "Simple continuation path, not a prediction engine.",
                action: "Use it as a baseline future path to compare other future signals against."
            )
        case .meanReversion:
            return InspectorInsight(
                title: rawValue,
                meaning: "Projects price bending back toward a recent average instead of extending the current move forever.",
                expectedRange: "Most useful after stretched moves or obvious dislocations.",
                action: "Use it to visualize where a pullback path could settle if momentum cools."
            )
        case .vwapCarry:
            return InspectorInsight(
                title: rawValue,
                meaning: "Carries the latest VWAP level flat into the foresight lane as a future value anchor.",
                expectedRange: "Acts like a fair-value reference for upcoming signals.",
                action: "Use it to judge whether future projections are drifting rich or cheap versus current flow."
            )
        case .volatilityCone:
            return InspectorInsight(
                title: rawValue,
                meaning: "Projects a central path with widening volatility bounds into the foresight lane.",
                expectedRange: "The cone broadens over time to reflect increasing uncertainty.",
                action: "Use the center as a bias path and the outer edges as expected movement limits."
            )
        case .bollingerMid, .bollingerUpper, .bollingerLower,
             .bollinger50Mid, .bollinger50Upper, .bollinger50Lower,
             .donchianUpper, .donchianLower, .donchian55Upper, .donchian55Lower,
             .keltnerMid, .keltnerUpper, .keltnerLower,
             .atrUpper, .atrLower, .regressionMid, .regressionUpper, .regressionLower,
             .volatilityConeMid, .volatilityConeUpper, .volatilityConeLower:
            return InspectorInsight(
                title: tooltipTitle,
                meaning: "Internal component line used by a parent indicator.",
                expectedRange: "This is usually managed together with its full indicator family.",
                action: "Use the parent indicator in the selector for the complete overlay set."
            )
        }
    }

    private var periodLabel: String {
        switch self {
        case .sma10:
            return "10"
        case .sma20:
            return "20"
        case .sma50:
            return "50"
        case .sma100:
            return "100"
        case .sma200:
            return "200"
        default:
            return ""
        }
    }

    var color: Color {
        switch self {
        case .sma10:
            return Color(red: 0.74, green: 0.90, blue: 0.68).opacity(0.86)
        case .sma20:
            return Color(red: 0.71, green: 0.88, blue: 0.62).opacity(0.84)
        case .sma50:
            return Color(red: 0.54, green: 0.82, blue: 0.90).opacity(0.82)
        case .sma100, .sma200:
            return Color(red: 0.58, green: 0.74, blue: 0.92).opacity(0.72)
        case .ema9, .ema12, .ema20:
            return Color(red: 0.95, green: 0.84, blue: 0.53).opacity(0.88)
        case .ema26, .ema50:
            return Color(red: 0.89, green: 0.63, blue: 0.57).opacity(0.82)
        case .ema100, .ema200:
            return Color(red: 0.94, green: 0.70, blue: 0.70).opacity(0.68)
        case .wma20:
            return Color(red: 0.64, green: 0.86, blue: 0.92).opacity(0.84)
        case .hma21:
            return Color(red: 0.82, green: 0.78, blue: 0.96).opacity(0.84)
        case .vwap:
            return Color(red: 0.90, green: 0.72, blue: 0.55).opacity(0.82)
        case .previousClose:
            return Color(red: 0.86, green: 0.86, blue: 0.88).opacity(0.62)
        case .bollingerBands, .bollingerBands50:
            return Color(red: 0.80, green: 0.70, blue: 0.88).opacity(0.75)
        case .donchianChannel, .donchian55:
            return Color(red: 0.63, green: 0.86, blue: 0.82).opacity(0.78)
        case .keltnerChannel:
            return Color(red: 0.93, green: 0.76, blue: 0.58).opacity(0.78)
        case .atrBands:
            return Color(red: 0.94, green: 0.64, blue: 0.58).opacity(0.72)
        case .regressionChannel:
            return Color(red: 0.70, green: 0.80, blue: 0.96).opacity(0.74)
        case .trendDrift:
            return Color(red: 0.95, green: 0.78, blue: 0.53).opacity(0.88)
        case .meanReversion:
            return Color(red: 0.72, green: 0.88, blue: 0.76).opacity(0.86)
        case .vwapCarry:
            return Color(red: 0.84, green: 0.84, blue: 0.96).opacity(0.84)
        case .volatilityCone:
            return Color(red: 0.88, green: 0.66, blue: 0.80).opacity(0.80)
        case .bollingerMid, .bollinger50Mid:
            return Color(red: 0.88, green: 0.80, blue: 0.94).opacity(0.62)
        case .bollingerUpper, .bollingerLower, .bollinger50Upper, .bollinger50Lower:
            return Color(red: 0.72, green: 0.64, blue: 0.82).opacity(0.56)
        case .donchianUpper, .donchianLower, .donchian55Upper, .donchian55Lower:
            return Color(red: 0.63, green: 0.86, blue: 0.82).opacity(0.62)
        case .keltnerMid:
            return Color(red: 0.97, green: 0.84, blue: 0.62).opacity(0.66)
        case .keltnerUpper, .keltnerLower:
            return Color(red: 0.93, green: 0.76, blue: 0.58).opacity(0.58)
        case .atrUpper, .atrLower:
            return Color(red: 0.94, green: 0.64, blue: 0.58).opacity(0.56)
        case .regressionMid:
            return Color(red: 0.76, green: 0.84, blue: 0.98).opacity(0.70)
        case .regressionUpper, .regressionLower:
            return Color(red: 0.70, green: 0.80, blue: 0.96).opacity(0.50)
        case .volatilityConeMid:
            return Color(red: 0.93, green: 0.74, blue: 0.84).opacity(0.76)
        case .volatilityConeUpper, .volatilityConeLower:
            return Color(red: 0.88, green: 0.66, blue: 0.80).opacity(0.54)
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .sma10, .sma20, .sma50, .sma100, .sma200,
             .ema9, .ema12, .ema20, .ema26, .ema50, .ema100, .ema200,
             .wma20, .hma21, .vwap, .previousClose,
             .trendDrift, .meanReversion, .vwapCarry:
            return 1.35
        case .bollingerBands, .bollingerBands50, .bollingerMid, .bollingerUpper, .bollingerLower,
             .bollinger50Mid, .bollinger50Upper, .bollinger50Lower,
             .donchianChannel, .donchian55, .donchianUpper, .donchianLower, .donchian55Upper, .donchian55Lower,
             .keltnerChannel, .keltnerMid, .keltnerUpper, .keltnerLower,
             .atrBands, .atrUpper, .atrLower, .regressionChannel, .regressionMid, .regressionUpper, .regressionLower,
             .volatilityCone, .volatilityConeMid, .volatilityConeUpper, .volatilityConeLower:
            return 1.0
        }
    }
}

private enum ForesightIndicatorGroup: String, CaseIterable, Identifiable {
    case trend
    case adaptive
    case priceStructure
    case volatility
    case channels
    case future

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trend:
            return "TREND"
        case .adaptive:
            return "ADAPTIVE"
        case .priceStructure:
            return "PRICE"
        case .volatility:
            return "VOLATILITY"
        case .channels:
            return "CHANNELS"
        case .future:
            return "FUTURE"
        }
    }

    var indicators: [ForesightIndicator] {
        switch self {
        case .trend:
            return [.sma10, .sma20, .sma50, .sma100, .sma200, .ema9, .ema12, .ema20, .ema26, .ema50, .ema100, .ema200]
        case .adaptive:
            return [.wma20, .hma21, .regressionChannel]
        case .priceStructure:
            return [.vwap, .previousClose]
        case .volatility:
            return [.bollingerBands, .bollingerBands50, .keltnerChannel, .atrBands]
        case .channels:
            return [.donchianChannel, .donchian55]
        case .future:
            return [.trendDrift, .meanReversion, .vwapCarry, .volatilityCone]
        }
    }
}

private struct GraphPoint: Identifiable {
    let index: Int
    let date: Date
    let value: Double
    let volume: Double?

    var id: TimeInterval { date.timeIntervalSince1970 }
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
