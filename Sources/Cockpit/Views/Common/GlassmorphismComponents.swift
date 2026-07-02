import SwiftUI
import Charts

// MARK: - Glassmorphism Component Library
//
// Reusable holographic UI components — glass cards, glow borders,
// neon effects, and animated indicators. Dark Tony Stark aesthetic.

// MARK: - Glass Card

/// A frosted glass card with optional glow border and title.
struct GlassCard<Content: View>: View {
    let title: String?
    let glowColor: Color
    let cornerRadius: CGFloat
    let entranceDelay: Double
    @State private var isVisible: Bool = false
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        glowColor: Color = .cyan,
        cornerRadius: CGFloat = 16,
        entranceDelay: Double = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.glowColor = glowColor
        self.cornerRadius = cornerRadius
        self.entranceDelay = entranceDelay
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                GlassCardHeader(title: title, glowColor: glowColor)
            }

            content()
                .padding(title != nil ? 16 : 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(glowColor.opacity(0.15), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(glowColor.opacity(0.05), lineWidth: 3)
                .blur(radius: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(entranceDelay)) {
                isVisible = true
            }
        }
    }
}

private struct GlassCardHeader: View {
    let title: String
    let glowColor: Color

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(glowColor)
                .tracking(2)

            Spacer()

            Rectangle()
                .fill(glowColor.opacity(0.15))
                .frame(width: 3, height: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(glowColor.opacity(0.05))
    }
}

// MARK: - Glow Border ViewModifier

struct GlowBorder: ViewModifier {
    let color: Color
    let radius: CGFloat
    let lineWidth: CGFloat
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color.opacity(0.2), lineWidth: lineWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color.opacity(0.08), lineWidth: lineWidth * 2)
                    .blur(radius: lineWidth * 3)
            )
            .shadow(color: color.opacity(0.15), radius: radius * 0.5, x: 0, y: 0)
    }
}

extension View {
    func glowBorder(color: Color = .cyan, radius: CGFloat = 16, lineWidth: CGFloat = 1) -> some View {
        modifier(GlowBorder(color: color, radius: radius, lineWidth: lineWidth))
    }
}

// MARK: - Neon Divider

struct NeonDivider: View {
    let color: Color
    let height: CGFloat

    init(color: Color = .cyan, height: CGFloat = 1) {
        self.color = color
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, color.opacity(0.3), color.opacity(0.6), color.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
    }
}

// MARK: - Animated Ring Progress

/// Circular progress indicator with neon glow
struct NeonRingProgress: View {
    let progress: Double // 0...1
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    @State private var animationProgress: Double = 0
    @State private var isGlowing: Bool = false

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.1), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animationProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.3), color, color.opacity(0.7)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(isGlowing ? 0.6 : 0.3), radius: isGlowing ? 10 : 6)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0), value: isGlowing)

            // Glow dot at tip
            if animationProgress > 0.01 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth * 2.5, height: lineWidth * 2.5)
                    .shadow(color: color.opacity(0.8), radius: 8)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(animationProgress * 360))
            }

            // Center content
            VStack(spacing: 2) {
                Text("\\(Int(progress * 100))")
                    .font(.system(size: size * 0.22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: size * 0.1, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animationProgress = progress
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0)) {
                isGlowing = true
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = newValue
            }
        }
    }
}

// MARK: - Sparkline Graph

/// Mini line chart for live metric history — uses Swift Charts (macOS 15+)
struct Sparkline: View {
    let data: [Double]     // Values 0...1 normalized
    let color: Color
    let height: CGFloat
    let showGlow: Bool

    @State private var drawProgress: CGFloat = 0

    init(data: [Double], color: Color = .cyan, height: CGFloat = 40, showGlow: Bool = true) {
        self.data = data
        self.color = color
        self.height = height
        self.showGlow = showGlow
    }

    private var indexedData: [(index: Int, value: Double)] {
        data.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        Chart(indexedData, id: \.index) { pt in
            LineMark(
                x: .value("Time", pt.index),
                y: .value("Value", pt.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .shadow(color: showGlow ? color.opacity(0.5) : .clear, radius: 4)

            AreaMark(
                x: .value("Time", pt.index),
                y: .value("Value", pt.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.15), color.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(drawProgress)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                drawProgress = 1
            }
        }
    }
}

// MARK: - Animated Background Gradient

/// Subtly shifting dark gradient background
struct AnimatedGradientBackground: View {
    @State private var phase: CGFloat = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.02, green: 0.02, blue: 0.06)

                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.08 + sin(phase) * 0.04),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.3 + cos(phase * 0.3) * 0.2, y: 0.4 + sin(phase * 0.4) * 0.3),
                    startRadius: 50,
                    endRadius: geo.size.width * 0.8
                )

                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.06 + cos(phase * 0.7) * 0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.7 + sin(phase * 0.5) * 0.2, y: 0.6 + cos(phase * 0.3) * 0.3),
                    startRadius: 50,
                    endRadius: geo.size.width * 0.7
                )
            }
            .ignoresSafeArea()
        }
        .onReceive(timer) { _ in
            phase += 0.01
        }
    }
}

// MARK: - Status Pulse Dot

struct StatusPulseDot: View {
    let isActive: Bool
    let color: Color

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseScale)

                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulseScale * 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.3), value: pulseScale)
            }

            Circle()
                .fill(isActive ? color : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .onAppear { pulseScale = isActive ? 1.8 : 1.0 }
        .onChange(of: isActive) { _, active in
            withAnimation { pulseScale = active ? 1.8 : 1.0 }
        }
    }
}

// MARK: - Data Stream Decoration

/// Animated data dots flowing along a line — decorative
struct DataStreamDecoration: View {
    let count: Int
    let color: Color
    let width: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let x = (CGFloat(i) / CGFloat(count - 1)) * size.width
                    let phase = (t * 2 + Double(i) * 0.6).truncatingRemainder(dividingBy: 2 * .pi)
                    let y = size.height / 2 + sin(phase) * size.height * 0.4
                    let alpha = 0.3 + sin(phase) * 0.3

                    let dot = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                    context.fill(dot, with: .color(color.opacity(alpha)))
                }
            }
        }
        .frame(height: 24)
        .frame(width: width)
    }
}

// MARK: - Holographic Label

struct HolographicLabel: View {
    let text: String
    let icon: String?
    let color: Color

    init(_ text: String, icon: String? = nil, color: Color = .cyan) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color.opacity(0.8))
                .tracking(1.2)
        }
    }
}

// MARK: - Scanning Line (reusable)

struct ScanningLine: View {
    let color: Color
    let speed: CGFloat
    @State private var offset: CGFloat = -100

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, color.opacity(0.08), color.opacity(0.15), color.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .offset(y: offset)
                .shadow(color: color.opacity(0.2), radius: 4, y: 0)
                .onAppear {
                    offset = -100
                    withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                        offset = geo.size.height + 100
                    }
                }
        }
    }
}

// MARK: - Floating Data Particles (SwiftUI)

/// Ambient floating data particles over content
struct FloatingDataParticles: View {
    let count: Int
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let seed = Double(i) * 137.508 // golden angle
                    let x = (sin(t * 0.3 + seed) * 0.5 + 0.5) * size.width
                    let y = (cos(t * 0.4 + seed) * 0.5 + 0.5) * size.height
                    let r = 1.0 + sin(t * 1.5 + seed) * 0.5
                    let alpha = 0.1 + sin(t * 2.0 + seed) * 0.15

                    let dot = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    context.fill(dot, with: .color(color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Metric Ring Card

/// Compact metric display with a neon ring around it
struct MetricRingCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let progress: Double // 0...1
    let tint: Color
    let delta: Double? // +/- percentage change, nil = no indicator

    @State private var isHovered: Bool = false

    init(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        progress: Double,
        tint: Color,
        delta: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.progress = progress
        self.tint = tint
        self.delta = delta
    }

    var body: some View {
        VStack(spacing: 12) {
            NeonRingProgress(progress: progress, color: tint, size: 60, lineWidth: 4)

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint.opacity(0.6))
                    .tracking(1.5)

                Text(subtitle)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Delta indicator
            if let delta = delta {
                HStack(spacing: 3) {
                    Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7, weight: .bold))
                    Text(String(format: "%.1f%%", abs(delta)))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(delta >= 0 ? .green : .orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((delta >= 0 ? Color.green : Color.orange).opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(isHovered ? 0.25 : 0.12), lineWidth: 1)
        )
        .shadow(color: tint.opacity(isHovered ? 0.1 : 0), radius: isHovered ? 10 : 0)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Scanning Line Overlay (compatibility)

/// Legacy compatibility shim — self-animating scanning line.
/// Kept for files already referencing ScanningLineOverlay from old ContentView.
struct ScanningLineOverlay: View {
    let offset: CGFloat

    var body: some View {
        ScanningLine(color: .cyan, speed: 4)
    }
}

// MARK: - Holographic Progress Bar (NEW)

/// Animated glowing horizontal progress bar for metrics
struct HolographicProgressBar: View {
    let value: Double          // 0...1
    let color: Color
    let height: CGFloat
    let showLabel: Bool

    @State private var animValue: Double = 0
    @State private var glowPulse: Bool = false

    init(value: Double, color: Color = .cyan, height: CGFloat = 6, showLabel: Bool = true) {
        self.value = value
        self.color = color
        self.height = height
        self.showLabel = showLabel
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.08))
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, CGFloat(animValue) * 200), height: height)
                    .shadow(color: color.opacity(glowPulse ? 0.4 : 0.15), radius: height)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(1.5), value: glowPulse)
            }

            if showLabel {
                Text("\\(Int(value * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animValue = value
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.5)) {
                glowPulse = true
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animValue = newValue
            }
        }
    }
}

// MARK: - Animated Value Text (NEW)

/// Digit-rolling counter for numeric values — animates between old and new
struct AnimatedValueText: View {
    let value: Int
    let font: Font
    let color: Color
    let duration: Double

    @State private var displayValue: Int = 0
    @State private var isAnimating: Bool = false

    init(value: Int, font: Font = .system(.body, design: .monospaced), color: Color = .white, duration: Double = 0.4) {
        self.value = value
        self.font = font
        self.color = color
        self.duration = duration
    }

    var body: some View {
        Text("\\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(displayValue)))
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: duration)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}

// MARK: - Data Glitch Effect (NEW)

/// Occasional "glitch" or data corruption animation on text
struct DataGlitchText: View {
    let text: String
        let color: Color

        @State private var glitching: Bool = false
        @State private var glitchOffset: CGFloat = 0
        @State private var glitchOpacity: CGFloat = 1.0
        let glitchInterval: Double // seconds between glitches

    init(_ text: String, color: Color = .cyan, glitchInterval: Double = 4.0) {
        self.text = text
        self.color = color
        self.glitchInterval = glitchInterval
    }

    var body: some View {
        ZStack {
            // Glitch ghost (offset copy)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.red.opacity(glitching ? 0.6 : 0))
                .offset(x: glitching ? glitchOffset : 0)

            // Blue ghost
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.blue.opacity(glitching ? 0.5 : 0))
                .offset(x: glitching ? -glitchOffset : 0)

            // Main text
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color.opacity(glitchOpacity))
        }
        .onAppear {
            triggerGlitch()
            startTimer()
        }
    }

    private func triggerGlitch() {
        let steps = 4
        let stepDuration = 0.04

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                if i.isMultiple(of: 2) {
                    glitchOffset = CGFloat.random(in: -2...2)
                    glitchOpacity = 0.7
                    glitching = true
                } else {
                    glitchOffset = 0
                    glitchOpacity = 1.0
                    glitching = false
                }
            }
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: glitchInterval, repeats: true) { _ in
            triggerGlitch()
        }
    }
}