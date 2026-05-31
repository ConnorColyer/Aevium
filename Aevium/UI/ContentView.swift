import SwiftUI
import AppKit
import Charts

struct ContentView: View {
    @State private var points = Self.makeSeries()

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

                    FocusedPriceGraph(points: points, time: t)
                        .padding(.top, 58)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
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

private struct GraphPoint: Identifiable {
    let index: Int
    let date: Date
    let value: Double

    var id: Int { index }
}

private struct FocusedPriceGraph: View {
    let points: [GraphPoint]
    let time: TimeInterval

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
                        Color(red: 0.31, green: 0.47, blue: 0.70).opacity(0.18),
                        Color(red: 0.22, green: 0.40, blue: 0.34).opacity(0.11),
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
            .lineStyle(.init(lineWidth: 2.2))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.60, green: 0.74, blue: 0.93),
                        Color(red: 0.55, green: 0.84, blue: 0.77)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.45, dash: [2.5, 4]))
                    .foregroundStyle(.white.opacity(0.10))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.30))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine(stroke: .init(lineWidth: 0.4))
                    .foregroundStyle(.white.opacity(0.06))
                AxisTick(stroke: .init(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.18))
                AxisValueLabel()
                    .foregroundStyle(.white.opacity(0.28))
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
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.top, 2)
                    .padding(.trailing, 6)
            }
        }
        .overlay {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.04), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(-13))
                .offset(x: sin(time * 0.18) * 220)
                .blendMode(.softLight)
                .allowsHitTesting(false)
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
