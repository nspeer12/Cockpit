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
    @State private var previousCPU: Double = 0
    @State private var previousMem: Double = 0
    @State private var previousDisk: Double = 0
    @State private var viewAppeared: Bool = false
    let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            FloatingDataParticles(count: 25, color: .cyan)
                .opacity(0.5)

            ScanningLine(color: .cyan, speed: 5)
                .opacity(0.3)

            VStack(spacing: 0) {
                Spacer()

                heroSection
                    .padding(.horizontal, 40)
                    .opacity(viewAppeared ? 1 : 0)
                    .scaleEffect(viewAppeared ? 1 : 0.95)
                    .blur(radius: viewAppeared ? 0 : 4)

                Spacer().frame(height: 16)

                // Metric Rings Row
                HStack(spacing: 16) {
                    MetricRingCard(
                        title: "CPU",
                        value: String(format: "%.1f%%", cpuPercent),
                        subtitle: formattedCores(),
                        icon: "cpu",
                        progress: min(cpuPercent / 100.0, 1.0),
                        tint: cpuPercent > 80 ? .red : cpuPercent > 50 ? .orange : .cyan,
                        delta: previousCPU > 0 ? cpuPercent - previousCPU : nil
                    )
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)

                    MetricRingCard(
                        title: "MEMORY",
                        value: formattedMemoryUsed(),
                        subtitle: formattedMemoryTotal(),
                        icon: "memorychip",
                        progress: min(memoryPercent / 100.0, 1.0),
                        tint: memoryPercent > 85 ? .red : memoryPercent > 60 ? .orange : .cyan,
                        delta: previousMem > 0 ? memoryPercent - previousMem : nil
                    )
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)

                    MetricRingCard(
                        title: "DISK",
                        value: formattedDiskUsed(),
                        subtitle: formattedDiskTotal(),
                        icon: "internaldrive",
                        progress: min(diskPercent / 100.0, 1.0),
                        tint: diskPercent > 90 ? .red : diskPercent > 70 ? .orange : .cyan,
                        delta: previousDisk > 0 ? diskPercent - previousDisk : nil
                    )
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)

                    MetricRingCard(
                        title: "MODEL",
                        value: shortModelName(activeModel),
                        subtitle: activeProvider.uppercased(),
                        icon: "brain.head.profile",
                        progress: 0.85,
                        tint: .purple
                    )
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                HStack(spacing: 16) {
                    GlassCard(title: "CPU HISTORY", glowColor: .cyan, entranceDelay: 0.3) {
                        Sparkline(data: cpuHistory, color: .cyan, height: 36)
                    }

                    GlassCard(title: "MEMORY HISTORY", glowColor: .blue, entranceDelay: 0.4) {
                        Sparkline(data: memHistory, color: .blue, height: 36)
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                HStack(spacing: 16) {
                    GlassCard(title: "EVENT LOG", glowColor: .green, entranceDelay: 0.5) {
                        LiveEventFeed(events: events)
                            .frame(height: 100)
                    }

                    GlassCard(title: "AMBIENT", glowColor: .purple, entranceDelay: 0.6) {
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

                hostIdentityBar
                    .padding(.horizontal, 40)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)

                Spacer().frame(height: 16)
            }
        }
        .onReceive(refreshTimer) { _ in
            refreshSystemInfo()
        }
        .onAppear {
            refreshSystemInfo()
            addStartupEvents()
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                viewAppeared = true
            }
        }
    }

    // MARK: - Formatted helpers (avoid nested string interpolation issues)

    private func formattedCores() -> String {
        "\(ProcessInfo.processInfo.processorCount) CORES"
    }

    private func formattedMemoryUsed() -> String {
        String(format: "%.1f", memoryUsed)
    }

    private func formattedMemoryTotal() -> String {
        "OF \(String(format: "%.0f", memoryTotal)) GB"
    }

    private func formattedDiskUsed() -> String {
        String(format: "%.1f", diskUsed)
    }

    private func formattedDiskTotal() -> String {
        "OF \(String(format: "%.0f", diskTotal)) GB"
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: 0) {
            HolographicHexCore()
                .frame(width: 160, height: 160)

            Spacer().frame(width: 36)

            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Text("HERMES")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan.opacity(0.15))
                        .blur(radius: 20)

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
                }

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
                previousCPU = cpuPercent
                previousMem = memoryPercent
                previousDisk = diskPercent

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

                self.cpuHistory.append(min(cpu / 100.0, 1.0))
                self.memHistory.append(min(mem.percentUsed / 100.0, 1.0))
                if self.cpuHistory.count > 60 { self.cpuHistory.removeFirst() }
                if self.memHistory.count > 60 { self.memHistory.removeFirst() }

                if abs(cpu - previousCPU) > 15 {
                    let msg = "CPU spike: \(String(format: "%.1f", cpu))%"
                    self.addEvent(msg, type: cpu > 80 ? .warning : .info)
                }
                if mem.percentUsed > 85 && previousMem <= 85 {
                    let msg = "Memory pressure: \(String(format: "%.1f", mem.percentUsed))%"
                    self.addEvent(msg, type: .warning)
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
        withAnimation(.easeOut(duration: 0.3)) {
            events.insert(event, at: 0)
        }
        if events.count > 50 { events.removeLast() }
    }

    private func shortModelName(_ full: String) -> String {
        full.components(separatedBy: "/").last ?? full
    }
}