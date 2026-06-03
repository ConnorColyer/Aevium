import SwiftUI
import AppKit
import Charts

private extension Notification.Name {
    static let aeviumExitOldStyleFullscreen = Notification.Name("aeviumExitOldStyleFullscreen")
    static let aeviumCloseWindow = Notification.Name("aeviumCloseWindow")
    static let aeviumMinimizeWindow = Notification.Name("aeviumMinimizeWindow")
}

private enum Motion {
    static let standard = Animation.easeInOut(duration: 0.22)
    static let micro = Animation.linear(duration: 0.10)
}

private enum WorkspaceTab {
    case market
    case overview
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
    @State private var selectedTab: WorkspaceTab = .market
    @State private var isOldStyleFullscreen = false
    @State private var bootMinimumElapsed = false
    @State private var bootFallbackElapsed = false
    @State private var bootSplashVisible = true
    @State private var bootTask: Task<Void, Never>?

    private let bootMinimumDuration: UInt64 = 650_000_000
    private let bootFallbackDuration: UInt64 = 2_400_000_000

    private let fallbackPoints = Self.makeSeries()

    private var visiblePoints: [GraphPoint] {
        let latestDate = market.points.last?.date ?? Date()
        let cutoff = latestDate.addingTimeInterval(-selectedRange.marketTimeRange.duration)
        let source = market.points.filter { $0.date >= cutoff }
        let live = source.enumerated().map { index, point in
            GraphPoint(index: index, date: point.date, value: point.price)
        }

        guard live.count > 1 else {
            return selectedRange.slice(from: fallbackPoints)
        }

        return live
    }

    var body: some View {
        let renderedPoints = visiblePoints
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
                    selectedTab: $selectedTab,
                    selectedRange: $selectedRange,
                    instrumentSymbol: market.selectedInstrument.compactTitle,
                    instrumentSession: market.selectedInstrument.session,
                    syncState: market.syncState,
                    analytics: analytics,
                    isUp: isUp,
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
            selectedTab = .market
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

        withAnimation(.easeOut(duration: 0.45)) {
            bootSplashVisible = false
        }
    }

    private static func analytics(from points: [GraphPoint]) -> MarketSeriesAnalytics {
        MarketSeriesCPU.analytics(
            timestamps: points.map { Int64($0.date.timeIntervalSince1970) },
            prices: points.map(\.value)
        )
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
    @State private var inspectorTargetOpen = true
    @State private var inspectorReveal: CGFloat = 1.0
    @State private var isSettingsPresented = false

    @ObservedObject var market: AeviumMarketViewModel
    let points: [GraphPoint]
    @Binding var selectedTab: WorkspaceTab
    @Binding var selectedRange: ChartRange
    let instrumentSymbol: String
    let instrumentSession: String
    let syncState: SyncState
    let analytics: MarketSeriesAnalytics
    let isUp: Bool
    let isOldStyleFullscreen: Bool

    private let inspectorMaxWidth: CGFloat = 304
    private var inspectorWidth: CGFloat { inspectorMaxWidth * inspectorReveal }
    private var inspectorDividerOpacity: Double { Double(inspectorReveal) }

    var body: some View {
        HStack(spacing: 0) {
            AeviumRail(
                isOldStyleFullscreen: isOldStyleFullscreen,
                selectedTab: selectedTab,
                onSelectMarketTab: { selectedTab = .market },
                onSelectOverviewTab: { selectedTab = .overview },
                onSettingsTapped: { isSettingsPresented = true }
            )

            VStack(spacing: 0) {
                WorkspaceTopBar()

                Rectangle()
                    .fill(Color.white.opacity(0.065))
                    .frame(height: 1)

                if selectedTab == .market {
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: 0) {
                            ChartStage(
                                points: points,
                                analytics: analytics,
                                selectedRange: $selectedRange,
                                isUp: isUp,
                                drawerReveal: inspectorReveal
                            )

                            Rectangle()
                                .fill(Color.white.opacity(0.065))
                                .frame(width: 1)
                                .opacity(inspectorDividerOpacity)

                            ZStack(alignment: .trailing) {
                                MarketInspector(
                                    points: points,
                                    analytics: analytics,
                                    instrumentSymbol: instrumentSymbol,
                                    instrumentSession: instrumentSession,
                                    selectedRange: selectedRange,
                                    isUp: isUp
                                )
                                .frame(width: inspectorMaxWidth, alignment: .trailing)
                                .offset(x: (1 - inspectorReveal) * 14)
                                .opacity(0.42 + (0.58 * inspectorReveal))
                            }
                            .frame(width: inspectorWidth, alignment: .trailing)
                            .clipped()
                            .allowsHitTesting(inspectorReveal > 0.01)
                        }

                        ChartTopControls(
                            market: market,
                            selectedRange: $selectedRange,
                            isInspectorOpen: inspectorTargetOpen,
                            onToggleInspector: toggleInspector
                        )
                        .padding(.top, 10)
                        .padding(.trailing, 20)
                        .offset(x: -(inspectorWidth + inspectorReveal))

                        SyncStatusStrip(state: syncState)
                            .padding(.top, 13)
                            .padding(.leading, 22)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                    .animation(Motion.standard, value: inspectorReveal)
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
        withAnimation(Motion.standard) {
            inspectorReveal = inspectorTargetOpen ? 1.0 : 0.0
        }
    }
}

private struct AeviumRail: View {
    let isOldStyleFullscreen: Bool
    let selectedTab: WorkspaceTab
    let onSelectMarketTab: () -> Void
    let onSelectOverviewTab: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            if isOldStyleFullscreen {
                FullscreenWindowControls()
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Spacer().frame(height: isOldStyleFullscreen ? 56 : 70)

            railButton("chart.xyaxis.line", active: selectedTab == .market, help: "Market view", action: onSelectMarketTab)
            railButton("square.grid.2x2", active: selectedTab == .overview, help: "Market overview", action: onSelectOverviewTab)
            railButton("waveform.path.ecg", active: false)

            Spacer()

            railButton("slider.horizontal.3", active: false, help: "Settings", action: onSettingsTapped)
        }
        .frame(width: 64)
        .background(Color.black.opacity(0.12))
    }

    private func railButton(_ icon: String, active: Bool, help: String? = nil, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? Color(red: 0.72, green: 0.88, blue: 0.82) : .white.opacity(0.34))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(active ? Color.white.opacity(0.075) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help ?? icon)
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
                                .fill(Color.black.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                                        .fill(Color.white.opacity(0.055))
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
                                    .fill(Color(red: 0.67, green: 0.86, blue: 0.78))
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
                                    .fill(Color.white.opacity(0.055))
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color(red: 0.08, green: 0.12, blue: 0.13).opacity(0.72),
                                Color.black.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
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

private struct ChartStage: View {
    let points: [GraphPoint]
    let analytics: MarketSeriesAnalytics
    @Binding var selectedRange: ChartRange
    let isUp: Bool
    let drawerReveal: CGFloat
    @State private var displayedXDomain: ClosedRange<Date>?
    @State private var displayedYAxis: YAxisConfiguration?
    @State private var lastCameraRange: ChartRange?

    private struct YAxisConfiguration: Equatable {
        let domain: ClosedRange<Double>
        let ticks: [Double]
        let step: Double
    }

    private struct CameraInput: Equatable {
        let range: ChartRange
        let count: Int
        let firstID: TimeInterval?
        let lastID: TimeInterval?
        let lowValue: Double
        let highValue: Double
        let lastValue: Double
    }

    private struct ChartSegment: Identifiable {
        let id: Int
        let points: [GraphPoint]
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

    private var yAxisConfiguration: YAxisConfiguration {
        makeYAxisConfiguration(lowValue: analytics.lowValue, highValue: analytics.highValue)
    }

    private var cameraInput: CameraInput {
        CameraInput(
            range: selectedRange,
            count: points.count,
            firstID: points.first?.id,
            lastID: points.last?.id,
            lowValue: analytics.lowValue,
            highValue: analytics.highValue,
            lastValue: analytics.lastValue
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

    var body: some View {
        GeometryReader { proxy in
            let xDomain = displayedXDomain ?? targetXDomain() ?? fallbackXDomain()
            let yAxis = displayedYAxis ?? yAxisConfiguration
            let ticks = adaptiveXAxisTicks(plotWidth: proxy.size.width, domain: xDomain)
            let labels = makeXAxisLabels(from: ticks)
            let segments = chartSegments()

            ZStack(alignment: .topTrailing) {
                Chart {
                    ForEach(segments) { segment in
                        ForEach(segment.points) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                yStart: .value("Base", yAxis.domain.lowerBound),
                                yEnd: .value("Price", point.value),
                                series: .value("Segment", segment.id)
                            )
                            .interpolationMethod(.linear)
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
                                y: .value("Price", point.value),
                                series: .value("Segment", segment.id)
                            )
                            .interpolationMethod(.linear)
                            .lineStyle(.init(lineWidth: 2.05, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(
                                isUp
                                    ? Color(red: 0.60, green: 0.86, blue: 0.75)
                                    : Color(red: 0.86, green: 0.68, blue: 0.68)
                            )
                        }
                    }

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
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yAxis.domain)
                .chartYAxis {
                    AxisMarks(position: .leading, values: yAxis.ticks) { value in
                        AxisGridLine(stroke: .init(lineWidth: 0.55, dash: [2, 8]))
                            .foregroundStyle(.white.opacity(0.13))
                        AxisValueLabel {
                            if let y = value.as(Double.self) {
                                Text(formatYAxisValue(y, step: yAxis.step))
                            }
                        }
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
        let lowerBound = latestDate.addingTimeInterval(-selectedRange.marketTimeRange.duration)
        return lowerBound...latestDate
    }

    private func fallbackXDomain() -> ClosedRange<Date> {
        let upperBound = Date()
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
        let normalized = min(max(shift / cadence, 0.65), 1.6)
        return 0.26 * normalized
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

        if targetFitsCurrent, currentSpan <= targetSpan * 1.8 {
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

    private func adaptiveXAxisTicks(plotWidth: CGFloat, domain: ClosedRange<Date>) -> [Date] {
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

    private func chartSegments() -> [ChartSegment] {
        let ordered = points.sorted { $0.date < $1.date }
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

        return deduped.count > 1 ? [ChartSegment(id: 0, points: deduped)] : []
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
    @Binding var selectedRange: ChartRange
    let isInspectorOpen: Bool
    let onToggleInspector: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            InstrumentSearchControl(market: market)
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
}

private struct InstrumentSearchControl: View {
    @ObservedObject var market: AeviumMarketViewModel

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
                .font(.system(size: 11.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 104)
                .onSubmit {
                    market.commitSearch()
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 35)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            if !market.searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(market.searchResults.prefix(6), id: \.id) { instrument in
                        Button {
                            market.selectInstrument(instrument)
                        } label: {
                            HStack(spacing: 8) {
                                Text(instrument.compactTitle)
                                    .font(.system(size: 11, weight: .semibold, design: .default))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .frame(width: 74, alignment: .leading)
                                Text(instrument.provider.uppercased())
                                    .font(.system(size: 8.5, weight: .semibold, design: .default))
                                    .tracking(1.0)
                                    .foregroundStyle(.white.opacity(0.36))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 27)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .frame(width: 180)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.095, blue: 0.11).opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .offset(y: 39)
                .zIndex(20)
            }
        }
        .frame(width: 146, height: 35, alignment: .topLeading)
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
                .fill(Color.black.opacity(0.13))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.065), lineWidth: 1))
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

private struct AeviumRangeSelector: View {
    @Binding var selectedRange: ChartRange

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(selectedRange == range ? .white.opacity(0.9) : .white.opacity(0.38))
                        .frame(width: 34, height: 27)
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
    let points: [GraphPoint]
    let analytics: MarketSeriesAnalytics
    let instrumentSymbol: String
    let instrumentSession: String
    let selectedRange: ChartRange
    let isUp: Bool

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
        (0..<20).map { i in
            let t = Double(i) / 19
            let wave = 0.30 * sin(t * .pi * 3.2) + 0.22 * cos(t * .pi * 5.4)
            let bias = (buyShare - 0.5) * 0.85
            return 0.5 + wave + bias
        }
    }

    private var depthSeries: [Double] {
        (0..<6).map { i in
            let t = Double(i) / 5
            let wave = 0.24 * cos(t * .pi * 2.3) + 0.16 * sin(t * .pi * 4.8)
            return (0.50 + wave + (buyShare - 0.5) * 0.55).clamped(to: 0.10...0.90)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
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
                        }

                        Spacer(minLength: 10)

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
                    }

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
                }
                card(tint: Color(red: 0.13, green: 0.20, blue: 0.28)) {
                    sectionHeader("ORDER FLOW")

                    HStack(alignment: .firstTextBaseline) {
                        Text("Imbalance")
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
                            title: "Order Imbalance",
                            meaning: "Net directional pressure from buying versus selling activity.",
                            expectedRange: "Normal rotational regimes often stay within -12% to +12%.",
                            action: "If imbalance persists above +/-20%, favor trend setups until momentum deteriorates."
                        )
                    )

                    SparklineArea(data: pulseSeries, color: Color(red: 0.64, green: 0.86, blue: 0.78))
                        .frame(height: 44)
                        .hoverInsight(
                            InspectorInsight(
                                title: "Flow Pulse",
                                meaning: "Short-horizon shape of demand/supply acceleration.",
                                expectedRange: "Smooth undulations indicate stable participation; abrupt spikes imply event-driven flow.",
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
                            action: "If both drifts widen with strong flow, favor continuation. If flow weakens, prepare for snapback."
                        )
                    )
                }

                card(tint: Color(red: 0.14, green: 0.22, blue: 0.20)) {
                    sectionHeader("MODEL SIGNALS")
                    signalBar("Flow", value: flowScore, color: Color(red: 0.54, green: 0.78, blue: 0.68))
                        .hoverInsight(
                            InspectorInsight(
                                title: "Flow Score",
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
                                meaning: "Composite certainty from flow quality, volatility and noise.",
                                expectedRange: "Actionable zone is usually above 55.",
                                action: "Below 45, prefer smaller position sizes and wait for structure confirmation."
                            )
                        )
                }

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
            .padding(.top, 22)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .background(Color.black.opacity(0.10))
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.03),
                            tint.opacity(0.16),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
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
        case "Flow", "Imbalance", "Pressure":
            return InspectorInsight(
                title: "Order Pressure",
                meaning: "Directional participation and dominance between buy and sell activity.",
                expectedRange: "Balanced tape usually lives near neutral; persistent extremes imply one-way flow.",
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
                action: "Outside +/-2, prepare for either continuation breakout or snapback depending on flow."
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

    var points: Int {
        switch self {
        case .twentyFiveMinutes: return 180
        case .hour: return 72
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

private struct GraphPoint: Identifiable {
    let index: Int
    let date: Date
    let value: Double

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
