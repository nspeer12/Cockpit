import SwiftUI

// MARK: - Top Command Bar — Enhanced

struct TopCommandBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let neoController: NEOController
    @State private var scanOffset: CGFloat = -60
    @State private var pulsateGlow: Bool = false

    var body: some View {
        HStack {
            // Logo + title
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "hexagon.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(pulsateGlow ? 0.6 : 0.2), radius: pulsateGlow ? 10 : 4)

                    // Scanning line across hexagon
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .cyan.opacity(0.15), .cyan.opacity(0.3), .cyan.opacity(0.15), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 28, height: 2)
                        .offset(y: scanOffset)
                        .blur(radius: 1)
                }
                .frame(width: 28, height: 28)

                Text("COCKPIT")
                    .font(.system(size: horizontalSizeClass == .compact ? 18 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: horizontalSizeClass == .compact ? 12 : 24) {
                LiveStatusIndicator()

                NEOButton(controller: neoController)

                Button(action: {}) {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 40)
        .padding(.vertical, horizontalSizeClass == .compact ? 12 : 16)
        .background(.ultraThinMaterial)
        .onAppear {
            // Scanning line animation
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                scanOffset = 60
            }
            // Pulsating glow
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsateGlow = true
            }
        }
    }
}

// MARK: - Live Status Indicator — Enhanced

struct LiveStatusIndicator: View {
    @State private var isLivePulse: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // Animated pulse ring
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isLivePulse ? 1.0 : 0.3)
                    .opacity(isLivePulse ? 0.0 : 0.5)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isLivePulse
                    )

                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green.opacity(0.6), radius: 4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("ALL SYSTEMS NOMINAL")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 3, height: 3)
                    Text("LIVE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.7))
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.green.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            isLivePulse = true
        }
    }
}