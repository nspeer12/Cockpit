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

                // Bottom Tab Bar - Only show on compact width (like iPad/iPhone)
                if #available(macOS 13.0, *) {
                    if NSApplication.shared.mainWindow?.contentView?.frame.width ?? 0 < 800 {
                        CustomTabBar(selectedTab: $selectedTab)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .background(.ultraThinMaterial)
                    }
                } else {
                    // Fallback for older macOS
                    CustomTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .background(.ultraThinMaterial)
                }
            }

            // JARVIS Overlay — visible when JARVIS mode is active
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

// MARK: - Mouse Parallax Tracker

@MainActor
final class MouseParallaxTracker {
    static let shared = MouseParallaxTracker()

    var onMove: ((CGPoint) -> Void)?
    private var monitor: Any?
    private let sensitivity: CGFloat = 0.01

    private init() {}

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self = self, let window = NSApp.keyWindow else { return event }

            let mouseInWindow = event.locationInWindow
            let windowSize = window.frame.size

            // Convert to normalized coordinates (-1...1)
            let nx = (mouseInWindow.x / windowSize.width - 0.5) * 2.0
            let ny = (mouseInWindow.y / windowSize.height - 0.5) * 2.0

            // Clamp
            let rx = min(1.0, max(-1.0, nx))
            let ry = min(1.0, max(-1.0, ny))

            DispatchQueue.main.async {
                self.onMove?(CGPoint(x: rx, y: ry))
            }

            return event
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

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

// MARK: - Overview View — Tony Stark Holographic Dashboard

struct OverviewView: View {
    @Environment(AmbientAwarenessManager.self) private var ambient
    @State private var cpuPercent: Double = 0
    @State private var memoryUsed: Double = 0
    @State private var memoryTotal: Double = 0
    @State private var memoryPercent: Double = 0
    @State private var diskUsed: Double = 0
    @State private var diskTotal: Double = 0
    @State private var diskPercent: Double = 0
    @State private var hostname: String = ""
    @State private var uptime: String = ""
    @State private var activeModel: String = ""
    @State private var activeProvider: String = ""
    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var memHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var events: [LiveEvent] = []
    let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Floating data particles behind everything
            FloatingDataParticles(count: 25, color: .cyan)
                .opacity(0.5)

            VStack(spacing: 0) {
                Spacer()

                // Central Hero Section
                heroSection
                    .padding(.horizontal, 40)

                Spacer().frame(height: 16)

                // Metric Rings Row
                HStack(spacing: 16) {
                    MetricRingCard(
                        title: "CPU",
                        value: String(format: "%.1f%%", cpuPercent),
                        subtitle: "\(ProcessInfo.processInfo.processorCount) CORES",
                        icon: "cpu",
                        progress: min(cpuPercent / 100.0, 1.0),
                        tint: cpuPercent > 80 ? .red : cpuPercent > 50 ? .orange : .cyan
                    )

                    MetricRingCard(
                        title: "MEMORY",
                        value: String(format: "%.1f", memoryUsed),
                        subtitle: "OF \(String(format: "%.0f", memoryTotal)) GB",
                        icon: "memorychip",
                        progress: min(memoryPercent / 100.0, 1.0),
                        tint: memoryPercent > 85 ? .red : memoryPercent > 60 ? .orange : .cyan
                    )

                    MetricRingCard(
                        title: "DISK",
                        value: String(format: "%.1f", diskUsed),
                        subtitle: "OF \(String(format: "%.0f", diskTotal)) GB",
                        icon: "internaldrive",
                        progress: min(diskPercent / 100.0, 1.0),
                        tint: diskPercent > 90 ? .red : diskPercent > 70 ? .orange : .cyan
                    )

                    MetricRingCard(
                        title: "MODEL",
                        value: shortModelName(activeModel),
                        subtitle: activeProvider.uppercased(),
                        icon: "brain.head.profile",
                        progress: 0.85,
                        tint: .purple
                    )
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                // Sparkline graphs row
                HStack(spacing: 16) {
                    GlassCard(title: "CPU HISTORY", glowColor: .cyan) {
                        Sparkline(data: cpuHistory, color: .cyan, height: 36)
                    }

                    GlassCard(title: "MEMORY HISTORY", glowColor: .blue) {
                        Sparkline(data: memHistory, color: .blue, height: 36)
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                // Bottom row: event feed + ambient sensors
                HStack(spacing: 16) {
                    // Live Event Feed
                    GlassCard(title: "EVENT LOG", glowColor: .green) {
                        LiveEventFeed(events: events)
                            .frame(height: 100)
                    }

                    // Ambient Sensors
                    GlassCard(title: "AMBIENT", glowColor: .purple) {
                        HStack(spacing: 12) {
                            CameraFeedView()
                                .frame(width: 120, height: 80)
                                .cornerRadius(8)

                            MicLevelMeterView()
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                // Host Identity Bar
                hostIdentityBar
                    .padding(.horizontal, 40)

                Spacer().frame(height: 16)
            }
        }
        .onReceive(refreshTimer) { _ in
            refreshSystemInfo()
        }
        .onAppear {
            refreshSystemInfo()
            addStartupEvents()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: 0) {
            HolographicHexCore()
                .frame(width: 160, height: 160)

            Spacer().frame(width: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text("HERMES")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.3), radius: 12)

                Text("COMMAND INTERFACE")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(8)

                HStack(spacing: 10) {
                    StatusPulseDot(isActive: true, color: .green)
                    Text("ALL SYSTEMS NOMINAL")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)

                // Quick stats row
                HStack(spacing: 20) {
                    HolographicLabel(hostname, icon: "desktopcomputer")
                    HolographicLabel("UPTIME \(uptime)", icon: "clock", color: .green)
                    HolographicLabel(shortModelName(activeModel), icon: "brain.head.profile", color: .purple)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Host Identity Bar

    private var hostIdentityBar: some View {
        HStack(spacing: 0) {
            HolographicLabel(hostname, icon: "desktopcomputer")

            Spacer()

            HStack(spacing: 16) {
                NeonDivider(color: .cyan.opacity(0.3), height: 1)
                    .frame(width: 60)

                HolographicLabel("UPTIME \(uptime)", icon: "clock", color: .green)
                HolographicLabel("\(ProcessInfo.processInfo.processorCount) CORES", icon: "cpu", color: .cyan)
                HolographicLabel(String(format: "%.0f GB RAM", memoryTotal), icon: "memorychip", color: .blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.cyan.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Refresh

    private func refreshSystemInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let cpu = SystemInfoService.cpuUsagePercent()
            let mem = SystemInfoService.memoryUsage()
            let disk = SystemInfoService.diskUsage()
            let name = SystemInfoService.hostname()
            let up = SystemInfoService.uptimeString()
            let model = SystemInfoService.activeModel()
            let provider = SystemInfoService.activeProvider()

            DispatchQueue.main.async {
                let oldCPU = self.cpuPercent
                self.cpuPercent = cpu
                self.memoryUsed = mem.usedGB
                self.memoryTotal = mem.totalGB
                self.memoryPercent = mem.percentUsed
                self.diskUsed = disk.usedGB
                self.diskTotal = disk.totalGB
                self.diskPercent = disk.percentUsed
                self.hostname = name
                self.uptime = up
                self.activeModel = model
                self.activeProvider = provider

                // Update histories
                self.cpuHistory.append(min(cpu / 100.0, 1.0))
                self.memHistory.append(min(mem.percentUsed / 100.0, 1.0))
                if self.cpuHistory.count > 60 { self.cpuHistory.removeFirst() }
                if self.memHistory.count > 60 { self.memHistory.removeFirst() }

                // Log significant events
                if abs(cpu - oldCPU) > 15 {
                    self.addEvent("CPU spike: \(String(format: "%.1f", cpu))%", type: cpu > 80 ? .warning : .info)
                }
                if mem.percentUsed > 85 && oldCPU <= 85 {
                    self.addEvent("Memory pressure: \(String(format: "%.1f", mem.percentUsed))%", type: .warning)
                }
            }
        }
    }

    private func addStartupEvents() {
        events = [
            LiveEvent(timestamp: Date(), text: "Cockpit initialized", type: .info),
            LiveEvent(timestamp: Date(), text: "RealityKit 3D engine online", type: .info),
            LiveEvent(timestamp: Date(), text: "System sensors active", type: .info),
        ]
    }

    private func addEvent(_ text: String, type: LiveEvent.EventType) {
        let event = LiveEvent(timestamp: Date(), text: text, type: type)
        events.insert(event, at: 0)
        if events.count > 50 { events.removeLast() }
    }

    private func shortModelName(_ full: String) -> String {
        full.components(separatedBy: "/").last ?? full
    }
}

// MARK: - Live Event

struct LiveEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let type: EventType

    enum EventType {
        case info, warning, error, success
        var color: Color {
            switch self {
            case .info: return .cyan
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
        var icon: String {
            switch self {
            case .info: return "circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
}

// MARK: - Live Event Feed

struct LiveEventFeed: View {
    let events: [LiveEvent]

    var body: some View {
        if events.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("AWAITING EVENTS...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(events.prefix(20))) { event in
                        HStack(spacing: 8) {
                            Image(systemName: event.type.icon)
                                .font(.system(size: 8))
                                .foregroundStyle(event.type.color)

                            Text(event.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)

                            Spacer()

                            Text(event.timestamp, style: .time)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(event.type.color.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
            }
            .defaultScrollAnchor(.top)
        }
    }
}

// MARK: - Holographic Hex Core (Enhanced)

struct HolographicHexCore: View {
    @State private var rotation: CGFloat = 0
    @State private var pulse: CGFloat = 1.0
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Outer ring with glow
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .purple, .cyan],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .rotationEffect(.degrees(rotation))
                .scaleEffect(pulse)
                .shadow(color: .cyan.opacity(0.4), radius: 10)

            Circle()
                .stroke(.cyan.opacity(0.25), lineWidth: 1)
                .frame(width: 110)
                .rotationEffect(.degrees(-rotation * 0.5))

            Circle()
                .stroke(.purple.opacity(0.15), lineWidth: 1)
                .frame(width: 140)
                .rotationEffect(.degrees(rotation * 0.3))

            // Inner hexagons
            Hexagon()
                .stroke(.cyan.opacity(0.55), lineWidth: 1.8)
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(rotation * 0.7))

            Hexagon()
                .stroke(.purple.opacity(0.35), lineWidth: 1.2)
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(-rotation * 0.3))

            Hexagon()
                .stroke(.blue.opacity(0.2), lineWidth: 0.8)
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(rotation * 0.4))

            // Center dot with strong glow
            Circle()
                .fill(.cyan)
                .frame(width: 9, height: 9)
                .shadow(color: .cyan.opacity(0.9), radius: 16)

            Circle()
                .fill(.cyan.opacity(0.3))
                .frame(width: 20, height: 20)
                .blur(radius: 6)
        }
        .onReceive(timer) { _ in
            rotation += 0.6
            pulse = 1.0 + sin(rotation * 0.04) * 0.06
        }
    }
}

// MARK: - Hexagon Shape

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat.pi / 3 * CGFloat(i) - CGFloat.pi / 6
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
