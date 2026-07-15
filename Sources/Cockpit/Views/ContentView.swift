import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedTab: Tab = .overview
    @State private var show3DBackground: Bool = true
    @State private var mouseRotation: CGPoint = .zero
    @State private var neoController = NEOController()

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case inference = "Inference"
        case projects = "Projects"
        case network = "Network"
        case node = "Node"
        case ambient = "Ambient"

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .inference: return "brain.head.profile"
            case .projects: return "folder"
            case .network: return "network"
            case .node: return "server.rack"
            case .ambient: return "eye"
            }
        }
    }

    var body: some View {
        ZStack {
            HolographicRealityBackground(rotation: mouseRotation, isVisible: show3DBackground)

            VStack(spacing: 0) {
                TopCommandBar(neoController: neoController)

                Group {
                    switch selectedTab {
                    case .overview: OverviewView().id("overview")
                    case .inference: InferencePanelView().id("inference")
                    case .projects: ProjectsView().id("projects")
                    case .network: NetworkView().id("network")
                    case .node: NodeView().id("node")
                    case .ambient: AmbientDashboardView().id("ambient")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: selectedTab)

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            }

            if neoController.jarvisActive || !neoController.responseText.isEmpty {
                NEOOverlay(controller: neoController)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            neoController.onCommandRecognized = { command in
                neoController.speak(NEOIdentity.acknowledgement(for: command))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitSelectTab)) { notification in
            guard let tab = notification.object as? Tab else { return }
            withAnimation(.easeInOut(duration: 0.25)) { selectedTab = tab }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitToggle3D)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { show3DBackground.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cockpitToggleNEO)) { _ in
            neoController.toggleNEOMode()
        }
    }
}
