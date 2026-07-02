import SwiftUI

// MARK: - Top Command Bar

struct TopCommandBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let jarvisController: JarvisController

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "hexagon.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)

                Text("COCKPIT")
                    .font(.system(size: horizontalSizeClass == .compact ? 18 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: horizontalSizeClass == .compact ? 12 : 24) {
                LiveStatusIndicator()

                JarvisButton(controller: jarvisController)

                Button(action: {}) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 40)
        .padding(.vertical, horizontalSizeClass == .compact ? 12 : 16)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Live Status Indicator

struct LiveStatusIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("ALL SYSTEMS NOMINAL")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}