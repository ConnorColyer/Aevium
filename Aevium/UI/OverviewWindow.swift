import SwiftUI

struct MarketOverviewTab: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model = MarketOverviewViewModel()

    private let columns = [
        GridItem(.flexible(minimum: 220), spacing: 14),
        GridItem(.flexible(minimum: 220), spacing: 14),
        GridItem(.flexible(minimum: 220), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    OverviewPulseCard(model: model)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        MoverSection(
                            title: "Top Gainers",
                            subtitle: "Strongest 24h upside",
                            movers: model.topGainers,
                            tint: Color(red: 0.54, green: 0.84, blue: 0.68),
                            onSelect: environment.openInstrument
                        )

                        MoverSection(
                            title: "Fastest Fades",
                            subtitle: "Largest 24h drawdowns",
                            movers: model.topLosers,
                            tint: Color(red: 0.92, green: 0.54, blue: 0.54),
                            onSelect: environment.openInstrument
                        )

                        MoverSection(
                            title: "Volume Leaders",
                            subtitle: "Most active USDT tape",
                            movers: model.volumeLeaders,
                            tint: Color(red: 0.58, green: 0.70, blue: 0.92),
                            onSelect: environment.openInstrument
                        )
                    }

                    FlowBoard(
                        movers: model.highEnergyMovers,
                        onSelect: environment.openInstrument
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverviewBackground())
        .onAppear {
            model.attach(engine: environment.marketDataEngine)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("AEVIUM")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3.0)
                    .foregroundStyle(.white.opacity(0.42))

                HStack(spacing: 9) {
                    Text("Market Overview")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("Binance public tape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.66, green: 0.84, blue: 0.76))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.35, green: 0.70, blue: 0.55).opacity(0.16))
                        )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(model.statusMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(model.statusIsError ? Color(red: 1.0, green: 0.52, blue: 0.52) : .white.opacity(0.48))

                if let lastUpdated = model.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }

            Button {
                model.refresh()
            } label: {
                Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.isLoading)
        }
        .padding(.leading, 22)
        .padding(.trailing, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

@MainActor
private final class MarketOverviewViewModel: ObservableObject {
    @Published private(set) var movers: [MarketMover] = []
    @Published private(set) var topGainers: [MarketMover] = []
    @Published private(set) var topLosers: [MarketMover] = []
    @Published private(set) var volumeLeaders: [MarketMover] = []
    @Published private(set) var highEnergyMovers: [MarketMover] = []
    @Published private(set) var advancers = 0
    @Published private(set) var decliners = 0
    @Published private(set) var breadth = 0.5
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage = "Preparing market overview"
    @Published private(set) var statusIsError = false
    @Published private(set) var lastUpdated: Date?

    private var engine: MarketDataEngine?
    private var loadTask: Task<Void, Never>?

    func attach(engine: MarketDataEngine) {
        guard self.engine == nil else { return }
        self.engine = engine
        refresh()
    }

    func refresh() {
        loadTask?.cancel()
        isLoading = true
        statusIsError = false
        statusMessage = "Scanning top movers"

        loadTask = Task { @MainActor [weak self] in
            guard let self, let engine = self.engine else { return }

            do {
                let movers = try await engine.topMovers(limit: 72)
                guard !Task.isCancelled else { return }

                self.movers = movers
                self.rebuildSections(from: movers)
                self.lastUpdated = Date()
                self.statusIsError = false
                self.statusMessage = movers.isEmpty ? "No movers returned" : "\(movers.count) active symbols"
                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.statusIsError = true
                self.statusMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func rebuildSections(from movers: [MarketMover]) {
        topGainers = Array(movers.filter(\.isUp).sorted { $0.percentChange > $1.percentChange }.prefix(8))
        topLosers = Array(movers.filter { !$0.isUp }.sorted { $0.percentChange < $1.percentChange }.prefix(8))
        volumeLeaders = Array(movers.sorted { $0.quoteVolume > $1.quoteVolume }.prefix(8))
        highEnergyMovers = Array(movers.sorted { lhs, rhs in
            (abs(lhs.percentChange) * log10(max(lhs.quoteVolume, 10))) >
                (abs(rhs.percentChange) * log10(max(rhs.quoteVolume, 10)))
        }.prefix(16))
        advancers = movers.filter(\.isUp).count
        decliners = movers.count - advancers
        breadth = movers.isEmpty ? 0.5 : Double(advancers) / Double(movers.count)
    }
}

private struct OverviewPulseCard: View {
    @ObservedObject var model: MarketOverviewViewModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tape Pulse")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(.white.opacity(0.42))

                Text(pulseTitle)
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Text("Advancers \(model.advancers) · Decliners \(model.decliners)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 9) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: model.breadth)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.58, green: 0.86, blue: 0.70),
                                    Color(red: 0.91, green: 0.56, blue: 0.56)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(model.breadth * 100))")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(width: 76, height: 76)

                Text("Breadth")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.055),
                            Color(red: 0.12, green: 0.18, blue: 0.20).opacity(0.62),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var pulseTitle: String {
        if model.movers.isEmpty { return "Loading" }
        if model.breadth > 0.58 { return "Risk-on rotation" }
        if model.breadth < 0.42 { return "Risk-off pressure" }
        return "Two-way market"
    }
}

private struct MoverSection: View {
    let title: String
    let subtitle: String
    let movers: [MarketMover]
    let tint: Color
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
            }

            VStack(spacing: 7) {
                ForEach(movers) { mover in
                    MoverRow(mover: mover, tint: tint, onSelect: onSelect)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        )
    }
}

private struct MoverRow: View {
    let mover: MarketMover
    let tint: Color
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        Button {
            onSelect(mover.instrument)
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mover.instrument.displaySymbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)

                        Text(compactPrice(mover.lastPrice))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.36))
                    }

                    Spacer()

                    Text(percent(mover.percentChange))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(mover.isUp ? Color(red: 0.58, green: 0.86, blue: 0.70) : Color(red: 0.94, green: 0.56, blue: 0.56))
                }

                MagnitudeBar(progress: mover.moveMagnitude, tint: tint)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
        }
        .buttonStyle(.plain)
        .help("Open \(mover.instrument.displaySymbol) in the chart")
    }
}

private struct FlowBoard: View {
    let movers: [MarketMover]
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("High Energy Board")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))

                    Text("Large move weighted by volume. Click anything to open it in the main chart.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 9)], spacing: 9) {
                ForEach(movers) { mover in
                    Button {
                        onSelect(mover.instrument)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(mover.instrument.displaySymbol)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .lineLimit(1)
                                Spacer()
                                Circle()
                                    .fill(mover.isUp ? Color(red: 0.55, green: 0.86, blue: 0.68) : Color(red: 0.92, green: 0.52, blue: 0.52))
                                    .frame(width: 6, height: 6)
                            }

                            Text(percent(mover.percentChange))
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundStyle(mover.isUp ? Color(red: 0.58, green: 0.86, blue: 0.70) : Color(red: 0.94, green: 0.56, blue: 0.56))

                            RangeRibbon(
                                low: mover.lowPrice,
                                high: mover.highPrice,
                                value: mover.lastPrice,
                                tint: mover.isUp ? Color(red: 0.55, green: 0.84, blue: 0.68) : Color(red: 0.90, green: 0.52, blue: 0.52)
                            )
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

private struct MagnitudeBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.075))

                Capsule()
                    .fill(tint.opacity(0.78))
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}

private struct RangeRibbon: View {
    let low: Double
    let high: Double
    let value: Double
    let tint: Color

    private var position: Double {
        let span = max(high - low, 0.0001)
        return min(max((value - low) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.075))

                Capsule()
                    .fill(tint.opacity(0.20))
                    .frame(width: proxy.size.width * position)

                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .offset(x: max(0, min(proxy.size.width - 6, proxy.size.width * position - 3)))
            }
        }
        .frame(height: 6)
    }
}

private struct OverviewBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.085, blue: 0.098)

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.29, blue: 0.27).opacity(0.34),
                    .clear
                ],
                center: UnitPoint(x: 0.18, y: 0.20),
                startRadius: 20,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color(red: 0.24, green: 0.18, blue: 0.30).opacity(0.28),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.10),
                startRadius: 20,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}

private func percent(_ value: Double) -> String {
    String(format: "%@%.2f%%", value >= 0 ? "+" : "", value)
}

private func compactPrice(_ value: Double) -> String {
    if value >= 1_000 {
        return String(format: "%.0f", value)
    }

    if value >= 1 {
        return String(format: "%.2f", value)
    }

    return String(format: "%.5f", value)
}
