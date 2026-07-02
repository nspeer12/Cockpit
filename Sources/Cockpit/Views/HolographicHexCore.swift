import SwiftUI

// MARK: - Holographic Hex Core — Enhanced

struct HolographicHexCore: View {
    @State private var rotation: CGFloat = 0
    @State private var pulse: CGFloat = 1.0
    @State private var breatheOuter: CGFloat = 1.0
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Outer ring with glow
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .purple, .cyan],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .rotationEffect(.degrees(rotation))
                .scaleEffect(pulse)
                .shadow(color: .cyan.opacity(0.4), radius: 10)

            Circle()
                .stroke(.cyan.opacity(0.25), lineWidth: 1)
                .frame(width: 110)
                .rotationEffect(.degrees(-rotation * 0.5))

            Circle()
                .stroke(.purple.opacity(0.15), lineWidth: 1)
                .frame(width: 140)
                .rotationEffect(.degrees(rotation * 0.3))

            // Orbiting data dots — outer ring
            ForEach(0..<6, id: \.self) { i in
                OrbitingDot(
                    index: i,
                    total: 6,
                    radius: 55,
                    rotation: rotation * 0.3,
                    color: .cyan,
                    size: 3,
                    glow: true
                )
            }

            // Orbiting data dots — inner ring
            ForEach(0..<4, id: \.self) { i in
                OrbitingDot(
                    index: i,
                    total: 4,
                    radius: 38,
                    rotation: -rotation * 0.5,
                    color: .purple,
                    size: 2.5,
                    glow: false
                )
            }

            // Inner hexagons
            Hexagon()
                .stroke(.cyan.opacity(0.55), lineWidth: 1.8)
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(rotation * 0.7))

            Hexagon()
                .stroke(.purple.opacity(0.35), lineWidth: 1.2)
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-rotation * 0.3))
                .scaleEffect(breatheOuter)

            Hexagon()
                .stroke(.blue.opacity(0.2), lineWidth: 0.8)
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(rotation * 0.4))

            // Inner particle field
            ForEach(0..<8, id: \.self) { i in
                InnerParticle(
                    index: i,
                    total: 8,
                    rotation: rotation * 0.8
                )
            }

            // Center dot with strong glow
            Circle()
                .fill(.cyan)
                .frame(width: 9, height: 9)
                .shadow(color: .cyan.opacity(0.9), radius: 16)
                .scaleEffect(breatheOuter)

            Circle()
                .fill(.cyan.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 6)
                .scaleEffect(breatheOuter * 1.2)
        }
        .onReceive(timer) { _ in
            rotation += 0.6
            pulse = 1.0 + sin(rotation * 0.04) * 0.06
            breatheOuter = 1.0 + sin(rotation * 0.015) * 0.04
        }
    }
}

// MARK: - Orbiting Dot

struct OrbitingDot: View {
    let index: Int
    let total: Int
    let radius: CGFloat
    let rotation: CGFloat
    let color: Color
    let size: CGFloat
    let glow: Bool

    var body: some View {
        let angle = (CGFloat(index) / CGFloat(total)) * 360 + rotation
        let rad = angle * .pi / 180
        let x = cos(rad) * radius
        let y = sin(rad) * radius

        return Circle()
            .fill(color.opacity(0.7))
            .frame(width: size, height: size)
            .shadow(color: glow ? color.opacity(0.5) : .clear, radius: glow ? 4 : 0)
            .offset(x: x, y: y)
    }
}

// MARK: - Inner Particle

struct InnerParticle: View {
    let index: Int
    let total: Int
    let rotation: CGFloat

    var body: some View {
        let angle = (CGFloat(index) / CGFloat(total)) * 360 + rotation
        let rad = angle * .pi / 180
        let radius: CGFloat = 14 + sin(rotation * 0.05 + CGFloat(index)) * 6
        let x = cos(rad) * radius
        let y = sin(rad) * radius
        let alpha: CGFloat = 0.2 + sin(rotation * 0.08 + CGFloat(index) * 2) * 0.15

        return Circle()
            .fill(.cyan.opacity(alpha))
            .frame(width: 2, height: 2)
            .offset(x: x, y: y)
    }
}

// MARK: - Hexagon Shape

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat.pi / 3 * CGFloat(i) - CGFloat.pi / 6
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}