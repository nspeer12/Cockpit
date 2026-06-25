import SwiftUI
import AVFoundation

/// Full ambient awareness dashboard tab for the Cockpit.
/// Combines camera preview, audio meter, ambient state indicator,
/// light level, and motion detection visualization.
struct AmbientDashboardView: View {
    @State private var manager = AmbientAwarenessManager()
    @State private var scanOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Scanning line background
            ScanningLineOverlay(offset: scanOffset)

            VStack(spacing: 0) {
                // Header
                headerBar

                if !manager.isAmbientEnabled {
                    // Disabled state — show enable prompt
                    disabledState
                } else {
                    // Active dashboard
                    activeDashboard
                }
            }
        }
        .onAppear {
            Task { await manager.enableAmbient() }
        }
        .onDisappear {
            manager.disableAmbient()
        }
        .onReceive(
            Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
        ) { _ in
            scanOffset += 2
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "eye.circle.fill")
                .font(.title3)
                .foregroundStyle(.cyan)

            Text("AMBIENT AWARENESS")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tracking(2)

            Spacer()

            // State orb
            stateOrb

            // Toggle
            Toggle("", isOn: Binding(
                get: { manager.isAmbientEnabled },
                set: { enabled in
                    Task {
                        if enabled {
                            await manager.enableAmbient()
                        } else {
                            manager.disableAmbient()
                        }
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
            .scaleEffect(0.8)
            .labelsHidden()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - State Orb

    private var stateOrb: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ambientStateColor)
                .frame(width: 10, height: 10)
                .shadow(color: ambientStateColor.opacity(0.8), radius: 6)
                .overlay(
                    Circle()
                        .stroke(ambientStateColor.opacity(0.4), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .scaleEffect(orbPulse ? 1.4 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: orbPulse
                        )
                )

            Text(manager.ambientState.rawValue.uppercased())
                .font(.caption.bold())
                .foregroundStyle(ambientStateColor)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .onAppear { orbPulse = true }
    }

    @State private var orbPulse = false

    private var ambientStateColor: Color {
        switch manager.ambientState {
        case .idle: return .gray
        case .active: return .cyan
        case .noisy: return .orange
        case .motionDetected: return .yellow
        case .conversation: return .green
        }
    }

    // MARK: - Disabled State

    private var disabledState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Ambient Awareness Disabled")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Enable to activate camera and microphone monitoring")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))

            // Permission status
            permissionStatusView

            Button("Enable") {
                Task { await manager.enableAmbient() }
            }
            .buttonStyle(GlassButtonStyle())
            .padding(.top, 8)

            Spacer()
        }
    }

    private var permissionStatusView: some View {
        HStack(spacing: 16) {
            permissionBadge(label: "Camera", authorized: manager.cameraAuthorized)
            permissionBadge(label: "Microphone", authorized: manager.micAuthorized)
        }
    }

    private func permissionBadge(label: String, authorized: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(authorized ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }

    // MARK: - Active Dashboard

    private var activeDashboard: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 600

            if isWide {
                HStack(spacing: 16) {
                    // Left: Camera preview
                    cameraSection
                        .frame(width: geo.size.width * 0.55)

                    // Right: Sensors
                    sensorSection
                        .frame(width: geo.size.width * 0.45)
                }
                .padding(16)
            } else {
                VStack(spacing: 16) {
                    cameraSection
                        .frame(height: geo.size.height * 0.55)
                    sensorSection
                }
                .padding(16)
            }
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        VStack(spacing: 8) {
            if manager.cameraRunning, manager.captureSessionValue != nil {
                // This won't work directly — need to expose session.
                // Using the @Observable manager's frame instead.
                cameraFallbackView
            } else {
                cameraFallbackView
            }
        }
    }

    private var cameraFallbackView: some View {
        ZStack {
            // Camera frame display
            if let frame = manager.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                    )
            } else {
                Rectangle()
                    .fill(.black.opacity(0.3))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text(manager.cameraRunning ? "Starting..." : "Camera Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    )
            }

            // Scanning line overlay
            ScanningLineOverlay(offset: scanOffset)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Corner brackets
            cornerBrackets

            // LIVE badge
            if manager.cameraRunning {
                VStack {
                    HStack {
                        Spacer()
                        Text("● LIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }

    private var cornerBrackets: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 28

            ZStack {
                // Top-left
                Path { p in
                    p.move(to: CGPoint(x: 6, y: 6 + len))
                    p.addLine(to: CGPoint(x: 6, y: 6))
                    p.addLine(to: CGPoint(x: 6 + len, y: 6))
                }
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)

                // Top-right
                Path { p in
                    p.move(to: CGPoint(x: w - 6 - len, y: 6))
                    p.addLine(to: CGPoint(x: w - 6, y: 6))
                    p.addLine(to: CGPoint(x: w - 6, y: 6 + len))
                }
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)

                // Bottom-left
                Path { p in
                    p.move(to: CGPoint(x: 6, y: h - 6 - len))
                    p.addLine(to: CGPoint(x: 6, y: h - 6))
                    p.addLine(to: CGPoint(x: 6 + len, y: h - 6))
                }
                .stroke(Color.purple.opacity(0.5), lineWidth: 1.5)

                // Bottom-right
                Path { p in
                    p.move(to: CGPoint(x: w - 6 - len, y: h - 6))
                    p.addLine(to: CGPoint(x: w - 6, y: h - 6))
                    p.addLine(to: CGPoint(x: w - 6, y: h - 6 - len))
                }
                .stroke(Color.purple.opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Sensor Section

    private var sensorSection: some View {
        VStack(spacing: 12) {
            // Audio meter
            AudioLevelMeterView(level: manager.micLevel, decibels: manager.micDecibels)

            // Light level
            sensorCard(
                icon: "sun.max",
                title: "AMBIENT LIGHT",
                value: String(format: "%.1f%%", manager.ambientLightLevel * 100),
                color: .yellow,
                progress: CGFloat(manager.ambientLightLevel)
            )

            // Motion level
            sensorCard(
                icon: "figure.walk.motion",
                title: "MOTION INDEX",
                value: String(format: "%.1f%%", manager.motionLevel * 100),
                color: manager.motionLevel > 0.1 ? .orange : .cyan,
                progress: CGFloat(min(manager.motionLevel * 10, 1.0))
            )

            // Mic authorization
            sensorCard(
                icon: manager.micAuthorized ? "mic.fill" : "mic.slash",
                title: "MIC STATUS",
                value: manager.micActive ? "Active" : "Inactive",
                color: manager.micActive ? .green : .secondary,
                progress: manager.micActive ? 1.0 : 0
            )

            // Camera status
            sensorCard(
                icon: manager.cameraAuthorized ? "camera.fill" : "camera.fill.badge.ellipsis",
                title: "CAMERA STATUS",
                value: manager.cameraRunning ? "Streaming" : "Stopped",
                color: manager.cameraRunning ? .green : .secondary,
                progress: manager.cameraRunning ? 1.0 : 0
            )

            Spacer(minLength: 0)
        }
    }

    private func sensorCard(
        icon: String,
        title: String,
        value: String,
        color: Color,
        progress: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.08))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.8))
                            .frame(width: geo.size.width * progress, height: 3)
                            .animation(.easeOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// Need to expose AVCaptureSession from the manager
extension AmbientAwarenessManager {
    var captureSessionValue: AVCaptureSession? {
        // Access private session for the CameraPreview NSViewRepresentable
        Mirror(reflecting: self).children
            .first(where: { $0.label == "captureSession" })?.value as? AVCaptureSession
    }
}
