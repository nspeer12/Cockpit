import SwiftUI

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
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        glowColor: Color = .cyan,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.glowColor = glowColor
        self.cornerRadius = cornerRadius
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
                .shadow(color: color.opacity(0.5), radius: 6)

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
                Text("\(Int(progress * 100))")
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
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animationProgress = newValue
            }
        }
    }
}

// MARK: - Sparkline Graph

/// Mini line chart for live metric history
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

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let h = geo.size.height
            let points = data.enumerated().map { (i, val) in
                CGPoint(
                    x: data.count > 1 ? CGFloat(i) / CGFloat(data.count - 1) * width : width / 2,
                    y: h - CGFloat(val) * h
                )
            }

            ZStack {
                // Filled area
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Glow line
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .shadow(color: showGlow ? color.opacity(0.5) : .clear, radius: 4)
                }
            }
        }
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

    @State private var pulseScale: CGFloat = 1.0
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
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
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