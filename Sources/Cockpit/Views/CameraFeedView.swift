import SwiftUI

/// Holographic-styled live camera preview panel with neon border and scanning-line overlay.
struct CameraFeedView: View {
    @Environment(AmbientAwarenessManager.self) private var ambient

    @State private var scanLineOffset: CGFloat = -100

    let scanTimer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Preview area
            previewArea
                .clipped()

            // Footer
            footer
        }
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(neonBorder)
        .overlay(outerGlow)
        .onReceive(scanTimer) { _ in
            guard ambient.cameraRunning else { return }
            // Advance the scanning line
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "camera.fill")
                .font(.caption)
                .foregroundStyle(.cyan)

            Text("LIVE FEED")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Spacer()

            Circle()
                .fill(ambient.cameraRunning ? .green : .secondary.opacity(0.3))
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(
                            ambient.cameraRunning ? .green.opacity(0.3) : .clear,
                            lineWidth: 3
                        )
                        .frame(width: 12, height: 12)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Preview

    private var previewArea: some View {
        ZStack {
            if let frame = ambient.currentFrame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

                // Holographic tint overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .cyan.opacity(0.04),
                                .clear,
                                .purple.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Scanning line
                ScanningLineOverlay(offset: scanLineOffset)
                    .onReceive(scanTimer) { _ in
                        scanLineOffset += 2.5
                        if scanLineOffset > 400 { scanLineOffset = -100 }
                    }
            } else {
                placeholderContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, idealHeight: 160, maxHeight: 200)
        .clipped()
    }

    private var placeholderContent: some View {
        VStack(spacing: 8) {
            Image(systemName: ambient.cameraRunning ? "camera.aperture" : "camera.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.3))
                .symbolEffect(.pulse, isActive: ambient.cameraRunning)

            Text(statusLabel)
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
                .tracking(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLabel: String {
        if !ambient.cameraAuthorized { return "CAMERA DENIED" }
        if ambient.cameraRunning { return "INITIALIZING..." }
        return "CAMERA OFF"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.grid.cross")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.4))

            Text("AVFoundation  •  Built-in Camera")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Neon border

    private var neonBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                LinearGradient(
                    colors: [.cyan.opacity(0.5), .blue.opacity(0.3), .cyan.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private var outerGlow: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(.cyan.opacity(0.08), lineWidth: 4)
            .blur(radius: 6)
    }
}
