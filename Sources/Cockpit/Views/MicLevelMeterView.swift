import SwiftUI

/// Real-time microphone level meter with animated bar-graph visualization.
/// Reads from AmbientAwarenessManager.micLevel (0 … 1 range).
struct MicLevelMeterView: View {
    @Environment(AmbientAwarenessManager.self) private var ambient

    private let barCount = 24

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Level bars
            levelBars
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            // Numeric readout
            readout
        }
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(neonBorder)
        .overlay(outerGlow)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.caption)
                .foregroundStyle(.purple)

            Text("MIC LEVEL")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Spacer()

            Circle()
                .fill(ambient.micActive ? .green : .secondary.opacity(0.3))
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(
                            ambient.micActive ? .green.opacity(0.3) : .clear,
                            lineWidth: 3
                        )
                        .frame(width: 12, height: 12)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Bars

    private var levelBars: some View {
        GeometryReader { geo in
            let barWidth = max(2.0, (geo.size.width - CGFloat(barCount - 1) * 3.0) / CGFloat(barCount))

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let threshold = Float(index) / Float(barCount)
                    let isActive = ambient.micLevel > threshold

                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(threshold: threshold, isActive: isActive))
                        .frame(width: barWidth)
                        .animation(.easeOut(duration: 0.06), value: isActive)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 60)
    }

    // MARK: - Readout

    private var readout: some View {
        HStack {
            Text("\(String(format: "%.1f", micLevelToDB(ambient.micLevel))) dB")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text(ambient.micActive ? "ACTIVE" : "INACTIVE")
                .font(.caption2)
                .foregroundStyle(ambient.micActive ? .green : .secondary.opacity(0.6))
                .tracking(1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Helpers

    private func barColor(threshold: Float, isActive: Bool) -> Color {
        guard isActive else { return .secondary.opacity(0.12) }
        if threshold > 0.85 { return .red.opacity(0.9) }
        if threshold > 0.55 { return .orange.opacity(0.8) }
        if threshold > 0.30 { return .purple.opacity(0.7) }
        return .cyan.opacity(0.6)
    }

    /// Convert normalized 0…1 level back to approximate dBFS.
    private func micLevelToDB(_ level: Float) -> Float {
        (level * 60.0) - 60.0
    }

    // MARK: - Decoration

    private var neonBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                LinearGradient(
                    colors: [.purple.opacity(0.5), .blue.opacity(0.3), .purple.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private var outerGlow: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(.purple.opacity(0.08), lineWidth: 4)
            .blur(radius: 6)
    }
}
