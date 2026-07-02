import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedTab: Tab = .overview
    @State private var show3DBackground: Bool = true
    @State private var mouseRotation: CGPoint = .zero
    @State private var jarvisController = JarvisController()
    @State private var tabTransition: TabTransitionDirection = .forward

    enum TabTransitionDirection {
        case forward, backward
    }

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

                // Main Content with crossfade transition
                Group {
                    switch selectedTab {
                    case .overview:
                        OverviewView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("overview")
                    case .inference:
                        InferencePanelView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("inference")
                    case .projects:
                        ProjectsView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("projects")
                    case .network:
                        NetworkView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("network")
                    case .node:
                        NodeView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("node")
                    case .ambient:
                        AmbientDashboardView()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(.easeOut(duration: 0.3)),
                                removal: .opacity.animation(.easeIn(duration: 0.15))
                            ))
                            .id("ambient")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: selectedTab)

                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            }
        }
    }
}