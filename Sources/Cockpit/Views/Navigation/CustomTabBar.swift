import SwiftUI

// MARK: - Custom Tab Bar — Animated Neon Pill

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Namespace private var tabNamespace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hoveredTab: ContentView.Tab? = nil
    @State private var pulsateActive: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: horizontalSizeClass == .compact ? 2 : 4) {
                        ZStack {
                            if selectedTab == tab {
                                // Glow behind active icon
                                Image(systemName: tab.icon + ".fill")
                                    .font(.system(size: horizontalSizeClass == .compact ? 16 : 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                                    .shadow(color: .cyan.opacity(0.6), radius: pulsateActive ? 8 : 3)
                                    .shadow(color: .cyan.opacity(0.3), radius: 16)
                            } else {
                                Image(systemName: tab.icon)
                                    .font(.system(size: horizontalSizeClass == .compact ? 16 : 18, weight: .medium))
                                    .foregroundStyle(hoveredTab == tab ? .white : .secondary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text(tab.rawValue.uppercased())
                            .font(.system(size: horizontalSizeClass == .compact ? 8 : 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? .white : hoveredTab == tab ? .white.opacity(0.7) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, horizontalSizeClass == .compact ? 8 : 12)
                    .background(
                        ZStack {
                            if selectedTab == tab {
                                // Animated neon pill
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .cyan.opacity(0.15),
                                                .blue.opacity(0.1),
                                                .purple.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        .cyan.opacity(pulsateActive ? 0.4 : 0.2),
                                                        .blue.opacity(pulsateActive ? 0.2 : 0.1),
                                                        .purple.opacity(pulsateActive ? 0.3 : 0.15)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: .cyan.opacity(pulsateActive ? 0.15 : 0.05), radius: 6)
                                    .matchedGeometryEffect(id: "tab_pill", in: tabNamespace, isSource: selectedTab == tab)
                            }
                        }
                    )
                    .cornerRadius(10)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.2)) {
                            hoveredTab = hovering ? tab : nil
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsateActive = true
            }
        }
    }
}