import SwiftUI

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: horizontalSizeClass == .compact ? 2 : 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: horizontalSizeClass == .compact ? 16 : 18, weight: .medium))

                        Text(tab.rawValue.uppercased())
                            .font(.system(size: horizontalSizeClass == .compact ? 8 : 10, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, horizontalSizeClass == .compact ? 8 : 12)
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .background(
                        selectedTab == tab ?
                        Color.white.opacity(0.08) : Color.clear
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}