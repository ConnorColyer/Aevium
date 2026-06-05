import SwiftUI

struct MarketOverviewTab: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model = MarketOverviewViewModel()

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 154), spacing: 10)
    ]

    private let laneColumns = [
        GridItem(.adaptive(minimum: 248), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(model: model)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    PulseHeroBand(model: model)

                    LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 10) {
                        PulseMetricCard(
                            title: "Active",
                            value: "\(model.movers.count)",
                            detail: "confirmed spot",
                            tint: Color(red: 0.70, green: 0.78, blue: 0.92)
                        )

                        PulseMetricCard(
                            title: "Breadth",
                            value: "\(Int(model.breadth * 100))%",
                            detail: "\(model.advancers) up / \(model.decliners) down",
                            tint: model.breadthTint
                        )

                        PulseMetricCard(
                            title: "Avg Move",
                            value: percent(model.averagePercentChange),
                            detail: "24h basket",
                            tint: model.averagePercentChange >= 0 ? PulsePalette.positive : PulsePalette.negative
                        )

                        PulseMetricCard(
                            title: "Turnover",
                            value: compactVolume(model.totalQuoteVolume),
                            detail: "Quote volume",
                            tint: Color(red: 0.86, green: 0.73, blue: 0.56)
                        )

                        PulseMetricCard(
                            title: "Trades",
                            value: compactCount(model.tradeTotal),
                            detail: "24h activity",
                            tint: Color(red: 0.74, green: 0.68, blue: 0.90)
                        )
                    }

                    PulseFocusStrip(
                        strongest: model.topGainers.first,
                        weakest: model.topLosers.first,
                        volumeLeader: model.volumeLeaders.first,
                        onSelect: environment.openInstrument
                    )

                    HomeMoverBoard(
                        movers: model.highEnergyMovers,
                        onSelect: environment.openInstrument
                    )

                    LazyVGrid(columns: laneColumns, alignment: .leading, spacing: 12) {
                        PulseMoverLane(
                            title: "Leaders",
                            subtitle: "Strong upside",
                            movers: model.topGainers,
                            tint: PulsePalette.positive,
                            onSelect: environment.openInstrument
                        )

                        PulseMoverLane(
                            title: "Pressure",
                            subtitle: "Largest downside",
                            movers: model.topLosers,
                            tint: PulsePalette.negative,
                            onSelect: environment.openInstrument
                        )

                        PulseMoverLane(
                            title: "Volume",
                            subtitle: "Most traded",
                            movers: model.volumeLeaders,
                            tint: Color(red: 0.66, green: 0.76, blue: 0.94),
                            onSelect: environment.openInstrument
                        )
                    }

                    PulseWatchlistStrip(
                        watchlist: environment.watchlist,
                        movers: model.movers,
                        onSelect: environment.openInstrument
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulseBackground())
        .onAppear {
            model.attach(engine: environment.marketDataEngine)
        }
        .onDisappear {
            model.cancel()
        }
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
    @Published private(set) var averagePercentChange = 0.0
    @Published private(set) var averageAbsMove = 0.0
    @Published private(set) var totalQuoteVolume = 0.0
    @Published private(set) var tradeTotal = 0
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage = "Preparing Home"
    @Published private(set) var statusIsError = false
    @Published private(set) var lastUpdated: Date?

    private var engine: MarketDataEngine?
    private var loadTask: Task<Void, Never>?

    var breadthTint: Color {
        if breadth >= 0.56 { return PulsePalette.positive }
        if breadth <= 0.44 { return PulsePalette.negative }
        return Color(red: 0.84, green: 0.74, blue: 0.58)
    }

    var pulseTitle: String {
        guard !movers.isEmpty else { return isLoading ? "Scanning" : "No Data" }
        if breadth >= 0.60 && averagePercentChange > 0 { return "Risk-On" }
        if breadth <= 0.40 && averagePercentChange < 0 { return "Risk-Off" }
        if averageAbsMove >= 8 { return "High Energy" }
        return "Mixed Tape"
    }

    func attach(engine: MarketDataEngine) {
        if self.engine == nil {
            self.engine = engine
        }
        refresh()
    }

    func refresh() {
        loadTask?.cancel()
        isLoading = true
        statusIsError = false
        statusMessage = "Scanning market"

        loadTask = Task { @MainActor [weak self] in
            guard let self, let engine = self.engine else { return }

            do {
                let movers = try await engine.topMovers(limit: 96)
                guard !Task.isCancelled else { return }

                self.movers = movers
                self.rebuildSections(from: movers)
                self.lastUpdated = Date()
                self.statusIsError = false
                self.statusMessage = movers.isEmpty ? "No confirmed symbols" : "Binance spot"
                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.statusIsError = true
                self.statusMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func rebuildSections(from movers: [MarketMover]) {
        let gainers = movers.filter(\.isUp)
        let losers = movers.filter { !$0.isUp }

        topGainers = Array(gainers.sorted { $0.percentChange > $1.percentChange }.prefix(7))
        topLosers = Array(losers.sorted { $0.percentChange < $1.percentChange }.prefix(7))
        volumeLeaders = Array(movers.sorted { $0.quoteVolume > $1.quoteVolume }.prefix(7))
        highEnergyMovers = Array(movers.sorted { lhs, rhs in
            energyScore(lhs) > energyScore(rhs)
        }.prefix(18))
        advancers = gainers.count
        decliners = movers.count - advancers
        breadth = movers.isEmpty ? 0.5 : Double(advancers) / Double(movers.count)
        averagePercentChange = movers.isEmpty ? 0 : movers.map(\.percentChange).reduce(0, +) / Double(movers.count)
        averageAbsMove = movers.isEmpty ? 0 : movers.map { abs($0.percentChange) }.reduce(0, +) / Double(movers.count)
        totalQuoteVolume = movers.map(\.quoteVolume).reduce(0, +)
        tradeTotal = movers.map(\.tradeCount).reduce(0, +)
    }

    private func energyScore(_ mover: MarketMover) -> Double {
        abs(mover.percentChange) * log10(max(mover.quoteVolume, 10))
    }
}

private struct HomeHeader: View {
    @ObservedObject var model: MarketOverviewViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("AEVIUM")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.38))

                HStack(spacing: 9) {
                    Text("Home")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))

                    Text(model.pulseTitle)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(model.breadthTint.opacity(0.95))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            Capsule(style: .continuous)
                                .fill(model.breadthTint.opacity(0.12))
                        )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.statusIsError ? PulsePalette.negative : PulsePalette.positive)
                        .frame(width: 6, height: 6)

                    Text(model.statusMessage)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(model.statusIsError ? PulsePalette.negative : .white.opacity(0.62))
                        .lineLimit(1)
                }

                if let lastUpdated = model.lastUpdated {
                    Text(lastUpdated.formatted(date: .omitted, time: .shortened))
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.055))
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.isLoading)
            .help("Refresh Home")
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(height: 58)
        .background(Color.black.opacity(0.12))
    }
}

private struct PulseHeroBand: View {
    @ObservedObject var model: MarketOverviewViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TAPE STATE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.38))

                        Text(model.pulseTitle)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer()

                    if model.isLoading && model.movers.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PulsePalette.positive)
                    }
                }

                HStack(spacing: 9) {
                    PulseSmallStat(title: "Advancers", value: "\(model.advancers)", tint: PulsePalette.positive)
                    PulseSmallStat(title: "Decliners", value: "\(model.decliners)", tint: PulsePalette.negative)
                    PulseSmallStat(title: "Avg Move", value: percent(model.averageAbsMove), tint: Color(red: 0.83, green: 0.76, blue: 0.58))
                }

                BreadthBalanceBar(breadth: model.breadth)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            .background(PulsePanelBackground())

            PulseBreadthDial(breadth: model.breadth, tint: model.breadthTint)
                .frame(width: 164, height: 156)
                .background(PulsePanelBackground())
        }
    }
}

private struct PulseSmallStat: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.34))

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct PulseBreadthDial: View {
    let breadth: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: breadth.clamped(to: 0...1))
                    .stroke(
                        tint.opacity(0.9),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(breadth * 100))")
                        .font(.system(size: 25, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("BREADTH")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
            .frame(width: 86, height: 86)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BreadthBalanceBar: View {
    let breadth: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PulsePalette.negative.opacity(0.32))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PulsePalette.positive.opacity(0.70))
                    .frame(width: max(8, proxy.size.width * breadth.clamped(to: 0...1)))
            }
        }
        .frame(height: 8)
    }
}

private struct PulseMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                Circle()
                    .fill(tint.opacity(0.9))
                    .frame(width: 6, height: 6)
            }

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(detail)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(PulsePanelBackground())
    }
}

private struct PulseFocusStrip: View {
    let strongest: MarketMover?
    let weakest: MarketMover?
    let volumeLeader: MarketMover?
    let onSelect: (InstrumentMetadata) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 230), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            PulseFocusCard(title: "Strongest", mover: strongest, tint: PulsePalette.positive, onSelect: onSelect)
            PulseFocusCard(title: "Weakest", mover: weakest, tint: PulsePalette.negative, onSelect: onSelect)
            PulseFocusCard(title: "Most Active", mover: volumeLeader, tint: Color(red: 0.70, green: 0.78, blue: 0.94), onSelect: onSelect)
        }
    }
}

private struct PulseFocusCard: View {
    let title: String
    let mover: MarketMover?
    let tint: Color
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        Button {
            if let mover {
                onSelect(mover.instrument)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .overlay(
                        Image(systemName: mover?.isUp == false ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint.opacity(0.9))
                    )
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.34))

                    Text(mover?.instrument.displaySymbol ?? "Loading")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)

                    Text(mover.map { compactVolume($0.quoteVolume) } ?? "--")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                }

                Spacer()

                Text(mover.map { percent($0.percentChange) } ?? "--")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(mover?.isUp == false ? PulsePalette.negative : tint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(PulsePanelBackground())
        }
        .buttonStyle(.plain)
        .disabled(mover == nil)
    }
}

private struct HomeMoverBoard: View {
    let movers: [MarketMover]
    let onSelect: (InstrumentMetadata) -> Void

    private var visibleMovers: [MarketMover] {
        Array(movers.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(
                title: "Now",
                trailing: movers.isEmpty ? "Loading" : "confirmed spot"
            )

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("Symbol")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Move")
                        .frame(width: 72, alignment: .trailing)
                    Text("Volume")
                        .frame(width: 82, alignment: .trailing)
                    Text("Range")
                        .frame(width: 94, alignment: .leading)
                }
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.30))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

                ForEach(visibleMovers) { mover in
                    HomeMoverBoardRow(mover: mover, onSelect: onSelect)

                    if mover.id != visibleMovers.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.055))
                            .frame(height: 1)
                            .padding(.leading, 10)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.028))
            )
        }
        .padding(12)
        .background(PulsePanelBackground())
    }
}

private struct HomeMoverBoardRow: View {
    let mover: MarketMover
    let onSelect: (InstrumentMetadata) -> Void

    private var tint: Color {
        mover.isUp ? PulsePalette.positive : PulsePalette.negative
    }

    var body: some View {
        Button {
            onSelect(mover.instrument)
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(tint.opacity(0.90))
                        .frame(width: 6, height: 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mover.instrument.displaySymbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(compactPrice(mover.lastPrice))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(percent(mover.percentChange))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint.opacity(0.96))
                    .frame(width: 72, alignment: .trailing)
                    .lineLimit(1)

                Text(compactVolume(mover.quoteVolume))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
                    .frame(width: 82, alignment: .trailing)
                    .lineLimit(1)

                RangeRibbon(
                    low: mover.lowPrice,
                    high: mover.highPrice,
                    value: mover.lastPrice,
                    tint: tint
                )
                .frame(width: 94)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help("Open \(mover.instrument.displaySymbol)")
    }
}

private struct PulseMoverLane: View {
    let title: String
    let subtitle: String
    let movers: [MarketMover]
    let tint: Color
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(title: title, trailing: subtitle)

            VStack(spacing: 6) {
                ForEach(movers) { mover in
                    PulseMoverRow(mover: mover, tint: tint, onSelect: onSelect)
                }
            }
        }
        .padding(12)
        .background(PulsePanelBackground())
    }
}

private struct PulseMoverRow: View {
    let mover: MarketMover
    let tint: Color
    let onSelect: (InstrumentMetadata) -> Void

    var body: some View {
        Button {
            onSelect(mover.instrument)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mover.instrument.displaySymbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)

                    Text(compactPrice(mover.lastPrice))
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.36))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(percent(mover.percentChange))
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(mover.isUp ? PulsePalette.positive : PulsePalette.negative)
                        .lineLimit(1)

                    MagnitudeBar(progress: mover.moveMagnitude, tint: mover.isUp ? PulsePalette.positive : PulsePalette.negative)
                        .frame(width: 70)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
        }
        .buttonStyle(.plain)
        .help("Open \(mover.instrument.displaySymbol)")
    }
}

private struct PulseWatchlistStrip: View {
    @ObservedObject var watchlist: InstrumentWatchlistStore
    let movers: [MarketMover]
    let onSelect: (InstrumentMetadata) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 156), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(title: "Watchlist", trailing: "\(watchlist.instruments.count)")

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(watchlist.instruments) { instrument in
                    WatchlistPulseTile(
                        instrument: instrument,
                        mover: movers.first { $0.instrument.id == instrument.id },
                        onSelect: onSelect
                    )
                }
            }
        }
        .padding(12)
        .background(PulsePanelBackground())
    }
}

private struct WatchlistPulseTile: View {
    let instrument: InstrumentMetadata
    let mover: MarketMover?
    let onSelect: (InstrumentMetadata) -> Void

    private var tint: Color {
        guard let mover else { return Color(red: 0.70, green: 0.76, blue: 0.86) }
        return mover.isUp ? PulsePalette.positive : PulsePalette.negative
    }

    var body: some View {
        Button {
            onSelect(instrument)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(instrument.displaySymbol)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)

                    Spacer()

                    Text(mover.map { percent($0.percentChange) } ?? "--")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.94))
                }

                RangeRibbon(
                    low: mover?.lowPrice ?? 0,
                    high: mover?.highPrice ?? 1,
                    value: mover?.lastPrice ?? 0.5,
                    tint: tint
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PulseSectionHeader: View {
    let title: String
    let trailing: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(trailing)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
        }
    }
}

private struct PulsePanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.075, green: 0.082, blue: 0.092).opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
                    .frame(width: max(7, proxy.size.width * progress.clamped(to: 0...1)))
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
        return ((value - low) / span).clamped(to: 0...1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(tint.opacity(0.22))
                    .frame(width: proxy.size.width * position)

                Capsule()
                    .fill(tint.opacity(0.95))
                    .frame(width: 7, height: 7)
                    .offset(x: max(0, min(proxy.size.width - 7, proxy.size.width * position - 3.5)))
            }
        }
        .frame(height: 7)
    }
}

private struct PulseBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.060, green: 0.067, blue: 0.076)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color(red: 0.10, green: 0.13, blue: 0.14).opacity(0.30),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                ForEach(0..<18, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.018))
                        .frame(height: 1)
                    Spacer()
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private enum PulsePalette {
    static let positive = Color(red: 0.55, green: 0.84, blue: 0.68)
    static let negative = Color(red: 0.92, green: 0.52, blue: 0.52)
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

private func compactVolume(_ value: Double) -> String {
    let absValue = abs(value)

    if absValue >= 1_000_000_000 {
        return String(format: "%.2fB", value / 1_000_000_000)
    }

    if absValue >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    }

    if absValue >= 1_000 {
        return String(format: "%.1fK", value / 1_000)
    }

    return String(format: "%.0f", value)
}

private func compactCount(_ value: Int) -> String {
    compactVolume(Double(value))
}

private func shortSymbol(_ symbol: String) -> String {
    symbol
        .replacingOccurrences(of: "/USDT", with: "")
        .replacingOccurrences(of: "USDT", with: "")
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
