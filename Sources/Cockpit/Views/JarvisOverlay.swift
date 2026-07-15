import SwiftUI

/// NEO voice presence overlay — holographic floating panel with
/// waveform visualization, transcript feedback, and command history.
struct NEOOverlay: View {
    let controller: NEOController
    @State private var waveformPhases: [Double] = Array(repeating: 0, count: 20)
    let waveformTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Top holographic accent bar
                HolographicAccentBar(color: accentColor)

                VStack(spacing: 14) {
                    // Status row with animated pulse
                    statusRow

                    // Waveform visualization (when active)
                    if controller.jarvisActive {
                        WaveformVisualization(phases: waveformPhases, color: accentColor)
                            .frame(height: 40)
                            .padding(.horizontal, 8)
                    }

                    // Current transcript
                    if !controller.currentTranscript.isEmpty {
                        transcriptView
                    }

                    // TTS response with typing animation
                    if !controller.responseText.isEmpty {
                        responseView
                    }

                    // Command history
                    if !controller.transcriptHistory.isEmpty {
                        historyView
                    }
                }
                .padding(18)
            }
            .background(
                // Frosted glass background
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                // Glow border
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.5),
                                accentColor.opacity(0.1),
                                Color.purple.opacity(0.3),
                                accentColor.opacity(0.1),
                                accentColor.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                // Outer glow
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accentColor.opacity(0.15), lineWidth: 3)
                    .blur(radius: 6)
            )
            // Floating holographic rings behind the panel
            .overlay(alignment: .top) {
                HolographicCornerRings(color: accentColor)
                    .offset(y: -20)
            }
            .shadow(color: accentColor.opacity(0.2), radius: 20, y: -4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.95))),
            removal: .opacity.combined(with: .move(edge: .bottom))
        ))
        .onReceive(waveformTimer) { _ in
            updateWaveform()
        }
    }

    // MARK: - Computed

    private var accentColor: Color {
        if controller.isSpeaking {
            return .purple
        } else if controller.wakeWordDetected {
            return .green
        } else {
            return .cyan
        }
    }

    // MARK: - Subviews

    private var statusRow: some View {
        HStack(spacing: 10) {
            // Animated status indicator
            ZStack {
                if controller.jarvisActive {
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .scaleEffect(controller.wakeWordDetected ? 2.0 : 1.3)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: controller.wakeWordDetected)

                    Circle()
                        .fill(accentColor.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .scaleEffect(controller.wakeWordDetected ? 1.8 : 1.0)
                        .opacity(0.5)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: controller.wakeWordDetected)
                }

                Circle()
                    .fill(controller.jarvisActive ? accentColor : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }

            Text(controller.statusMessage)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // NEO label
            Text("N.E.O.")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor.opacity(0.6))
                .tracking(3)
        }
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HolographicLabel("LISTENING", icon: "ear", color: accentColor)

            Text(controller.currentTranscript)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(10)
                .background(accentColor.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var responseView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HolographicLabel("RESPONSE", icon: "message", color: .purple)

            Text(controller.responseText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(12)
                .background(.purple.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.purple.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HolographicLabel("HISTORY", icon: "clock.arrow.2.circlepath", color: .secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(controller.transcriptHistory.suffix(5)) { entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.isCommand ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 5, height: 5)

                            Text(entry.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(entry.isCommand ? .green.opacity(0.8) : .secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxHeight: 100)
            .padding(10)
            .background(.white.opacity(0.03))
            .cornerRadius(8)
        }
    }

    // MARK: - Waveform

    private func updateWaveform() {
        guard controller.jarvisActive else { return }
        for i in 0..<waveformPhases.count {
            let seed = Double(i) * 0.5
            let speed: Double = controller.isSpeaking ? 3.0 : controller.wakeWordDetected ? 2.0 : 1.2
            waveformPhases[i] = sin(CACurrentMediaTime() * speed + seed) * (0.3 + Double(i).truncatingRemainder(dividingBy: 3) * 0.25)
        }
    }
}

// MARK: - Waveform Visualization

struct WaveformVisualization: View {
    let phases: [Double]
    let color: Color
    let barCount: Int = 20

    init(phases: [Double], color: Color) {
        self.phases = phases
        self.color = color
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(phases.count, barCount), id: \.self) { i in
                let amplitude = abs(phases[i])
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.7), color],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(4, amplitude * 36))
                    .shadow(color: color.opacity(amplitude * 0.5), radius: 2)
            }
        }
    }
}

// MARK: - Holographic Accent Bar

private struct HolographicAccentBar: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(color.opacity(0.1))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, color, .clear],
                            startPoint: UnitPoint(x: phase, y: 0),
                            endPoint: UnitPoint(x: phase + 0.3, y: 0)
                        )
                    )
                    .opacity(0.6)
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
        }
        .frame(height: 3)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 18, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 18,
            style: .continuous
        ))
    }
}

// MARK: - Holographic Corner Rings

private struct HolographicCornerRings: View {
    let color: Color
    @State private var rotation: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Left ring
            partialRing(color: color, rotation: rotation)

            Spacer()

            // Right ring
            partialRing(color: color, rotation: -rotation)
                .scaleEffect(x: -1, y: 1)
        }
        .frame(height: 20)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private func partialRing(color: Color, rotation: CGFloat) -> some View {
        Circle()
            .trim(from: 0.25, to: 0.75)
            .stroke(
                AngularGradient(
                    colors: [color.opacity(0.0), color.opacity(0.4), color.opacity(0.0)],
                    center: .center
                ),
                lineWidth: 1.5
            )
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - NEO Button (Enhanced with Hex Ring)

/// Glowing NEO presence button with hex ring animation.
struct NEOButton: View {
    let controller: NEOController
    @State private var hexRotation: CGFloat = 0

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                controller.toggleNEOMode()
            }
        }) {
            ZStack {
                // Hex ring (visible when active)
                if controller.jarvisActive {
                    HexRing(color: accentColor, rotation: hexRotation)
                        .frame(width: 52, height: 52)
                }

                // Pulse rings
                if controller.jarvisActive {
                    pulseRings
                }

                // Icon circle
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(iconBackground)
                    )
                    .overlay(
                        Circle()
                            .stroke(iconColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: iconColor.opacity(0.3), radius: controller.jarvisActive ? 8 : 0)
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    hexRotation = 360
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(controller.jarvisActive ? "Take NEO offline" : "Bring NEO online")
    }

    // MARK: - Pulse Rings

    @ViewBuilder
    private var pulseRings: some View {
        let ringCount = controller.wakeWordDetected || controller.isSpeaking ? 4 : 2
        let baseDelay: Double = controller.wakeWordDetected || controller.isSpeaking ? 0.3 : 0.6

        ForEach(0..<ringCount, id: \.self) { index in
            PulseRing(
                color: accentColor,
                delay: baseDelay * Double(index),
                baseOpacity: controller.wakeWordDetected || controller.isSpeaking ? 0.4 : 0.15,
                isActive: controller.jarvisActive
            )
        }
    }

    // MARK: - Helpers

    private var accentColor: Color {
        if !controller.jarvisActive { return .secondary }
        if controller.isSpeaking { return .purple }
        if controller.wakeWordDetected { return .green }
        return .cyan
    }

    private var iconName: String {
        if controller.isSpeaking {
            return "waveform"
        } else if controller.wakeWordDetected {
            return "mic.fill.badge.ellipsis"
        } else if controller.jarvisActive {
            return "mic.fill"
        } else {
            return "mic.slash"
        }
    }

    private var iconColor: Color {
        if !controller.jarvisActive { return .secondary }
        if controller.isSpeaking { return .purple }
        if controller.wakeWordDetected { return .green }
        return .cyan
    }

    private var iconBackground: Color {
        if controller.jarvisActive {
            if controller.wakeWordDetected {
                return .green.opacity(0.15)
            } else if controller.isSpeaking {
                return .purple.opacity(0.15)
            } else {
                return .cyan.opacity(0.1)
            }
        } else {
            return .secondary.opacity(0.05)
        }
    }
}

// MARK: - Hex Ring

private struct HexRing: View {
    let color: Color
    let rotation: CGFloat
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Hexagon()
                .stroke(color.opacity(0.25), lineWidth: 1.2)
                .rotationEffect(.degrees(rotation * 0.7))
                .scaleEffect(pulse)

            Hexagon()
                .stroke(color.opacity(0.12), lineWidth: 1.2)
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(-rotation * 0.5))
                .scaleEffect(pulse * 0.85)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = 1.1
            }
        }
    }
}

// MARK: - Pulse Ring

private struct PulseRing: View {
    let color: Color
    let delay: Double
    let baseOpacity: Double
    let isActive: Bool

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 1.5)
            .frame(width: 38, height: 38)
            .scaleEffect(scale)
            .animation(
                .easeOut(duration: delay * 2.5)
                .repeatForever(autoreverses: false),
                value: scale
            )
            .onAppear { animate() }
            .onChange(of: isActive) { _, newValue in
                if newValue { animate() }
            }
    }

    private func animate() {
        opacity = 0
        scale = 0.8
        withAnimation(.easeOut(duration: delay * 2.5).repeatForever(autoreverses: false)) {
            opacity = baseOpacity
            scale = 2.2
        }
    }
}