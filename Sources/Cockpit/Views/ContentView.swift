import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedTab: Tab = .overview
    @State private var show3DBackground: Bool = true
    @State private var mouseRotation: CGPoint = .zero
    @State private var jarvisController = JarvisController()

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
            // 3D RealityKit Background with mouse parallax
            HolographicRealityBackground(
                rotation: mouseRotation,
                isVisible: show3DBackground
            )

            VStack(spacing: 0) {
                // Top Command Bar
                TopCommandBar(jarvisController: jarvisController)

                // Main Content
                Group {
                    switch selectedTab {
                    case .overview:
                        OverviewView()
                    case .inference:
                        InferencePanelView()
                    case .projects:
                        ProjectsView()
                    case .network:
                        NetworkView()
                    case .node:
                        NodeView()
                    case .ambient:
                        AmbientDashboardView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Tab Bar
                if #available(macOS 13.0, *) {
                    if NSApplication.shared.mainWindow?.contentView?.frame.width ?? 0 < 800 {
                        CustomTabBar(selectedTab: $selectedTab)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .background(.ultraThinMaterial)
                    }
                } else {
                    CustomTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .background(.ultraThinMaterial)
                }
            }

            // JARVIS Overlay
            if jarvisController.jarvisActive {
                JarvisOverlay(controller: jarvisController)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: jarvisController.jarvisActive)
        .onKeyPress(.space) {
            show3DBackground.toggle()
            return .handled
        }
        .onAppear {
            setupMouseTracking()
        }
        .onDisappear {
            teardownMouseTracking()
        }
    }

    // MARK: - Mouse Parallax Tracking

    private func setupMouseTracking() {
        MouseParallaxTracker.shared.onMove = { rotation in
            mouseRotation = rotation
        }
        MouseParallaxTracker.shared.start()
    }

    private func teardownMouseTracking() {
        MouseParallaxTracker.shared.stop()
    }
}