import SwiftUI

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