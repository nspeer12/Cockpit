import SwiftUI

/// Real-time audio level meter with holographic Cockpit styling.
struct AudioLevelMeterView: View {
    let level: Float       // 0.0–1.0
    let decibels: Float    // dB FS

    var body: some View {
        VStack(spacing: 8) {
            // Label
            HStack {
                Image(systemName: "mic")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                Text("AUDIO INPUT")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Spacer()
                Text(String(format: "%.1f dB", decibels))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(levelColor)
            }

            // Meter bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.06))

                    // Active fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, levelColor, levelColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(level)))
                        .animation(.easeOut(duration: 0.1), value: level)

                    // Tick marks
                    ForEach([0.25, 0.5, 0.75], id: \.self) { tick in
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 1, height: geo.size.height)
                            .offset(x: geo.size.width * tick)
                    }
                }
            }
            .frame(height: 16)

            // Level label
            Text(String(format: "%.0f%%", level * 100))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
    }

    private var levelColor: Color {
        if level > 0.7 { return .red }
        if level > 0.4 { return .orange }
        if level > 0.1 { return .cyan }
        return .gray
    }
}
