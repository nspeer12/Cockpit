import SwiftUI

struct NodeView: View {
    @State private var nodeStatus = NodeStatus()
    @State private var isLoading = true
    let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack {
                    Text("HERMES NODE")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        StatusPill(status: nodeStatus.isHealthy ? "HEALTHY" : "DEGRADED")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Identity
                NodeSection(title: "IDENTITY") {
                    NodeInfoRow(label: "Hostname", value: nodeStatus.hostname)
                    NodeInfoRow(label: "Profile", value: nodeStatus.profile)
                    NodeInfoRow(label: "Uptime", value: nodeStatus.uptime)
                }

                // Model & Inference
                NodeSection(title: "INFERENCE") {
                    NodeInfoRow(label: "Primary Provider", value: nodeStatus.primaryProvider)
                    NodeInfoRow(label: "Active Model", value: nodeStatus.activeModel)
                    NodeInfoRow(label: "Fallback", value: nodeStatus.fallbackProvider)
                }

                // System Resources
                NodeSection(title: "SYSTEM") {
                    NodeInfoRow(label: "CPU", value: nodeStatus.cpuUsage)
                    NodeInfoRow(label: "Memory", value: nodeStatus.memoryUsage)
                    NodeInfoRow(label: "Disk", value: nodeStatus.diskUsage)
                }

                // Remote Agents
                if !nodeStatus.remoteAgents.isEmpty {
                    NodeSection(title: "REMOTE AGENTS") {
                        ForEach(nodeStatus.remoteAgents) { agent in
                            RemoteAgentRow(agent: agent)
                        }
                    }
                }

                // Cron Jobs
                if !nodeStatus.activeCronJobs.isEmpty {
                    NodeSection(title: "ACTIVE CRON") {
                        ForEach(nodeStatus.activeCronJobs) { job in
                            CronJobRow(job: job)
                        }
                    }
                }
            }
            .padding(.bottom, 60)
        }
        .onReceive(refreshTimer) { _ in
            Task { await loadRealData() }
        }
        .task {
            await loadRealData()
        }
    }

    private func loadRealData() async {
        isLoading = true
        defer { isLoading = false }

        // System info from local calls
        let hostname = SystemInfoService.hostname()
        let uptime = SystemInfoService.uptimeString()
        let cpu = SystemInfoService.cpuUsagePercent()
        let mem = SystemInfoService.memoryUsage()
        let disk = SystemInfoService.diskUsage()
        let model = SystemInfoService.activeModel()
        let provider = SystemInfoService.activeProvider()

        // Hermes config for profile and fallback
        let profile = await runHermesCommand(args: ["config", "get", "profile"]) ?? "default"
        let fallback = await runHermesCommand(args: ["config", "get", "fallback_model"]) ?? "none"

        // Cron jobs
        let cronJobs = await fetchCronJobs()

        // Remote agents (from known endpoints)
        let agents = await checkRemoteAgents()

        await MainActor.run {
            nodeStatus = NodeStatus(
                hostname: hostname,
                profile: profile,
                uptime: uptime,
                primaryProvider: "\(provider) (\(model))",
                activeModel: model,
                fallbackProvider: fallback,
                cpuUsage: String(format: "%.1f%%", cpu),
                memoryUsage: String(format: "%.1f GB / %.0f GB", mem.usedGB, mem.totalGB),
                diskUsage: String(format: "%.1f GB / %.0f GB", disk.usedGB, disk.totalGB),
                isHealthy: true,
                remoteAgents: agents,
                activeCronJobs: cronJobs
            )
        }
    }

    private func runHermesCommand(args: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["hermes"] + args
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchCronJobs() async -> [CronJob] {
        guard let output = await runHermesCommand(args: ["cron", "list"]) else {
            return []
        }

        // Parse cron list output
        var jobs: [CronJob] = []
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("ID") else { continue }
            // Format: job_id  schedule  status
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }
            let name = parts[0]
            let schedule = parts.dropFirst().joined(separator: " ")
            jobs.append(CronJob(name: name, schedule: schedule, lastRun: "—"))
        }
        return jobs
    }

    private func checkRemoteAgents() async -> [RemoteAgent] {
        var agents: [RemoteAgent] = []
        for endpoint in RemoteModelEndpoint.defaults {
            let status = await RemoteModelHealthChecker.check(endpoint)
            let agentStatus: AgentStatus = status.state == .online ? .online : .offline
            agents.append(RemoteAgent(name: endpoint.name, status: agentStatus, lastSeen: agentStatus == .online ? "just now" : "unreachable"))
        }
        return agents
    }
}

// MARK: - Supporting Views

struct NodeSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .padding(.horizontal, 40)
        }
    }
}

struct NodeInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.white.opacity(0.08)),
            alignment: .bottom
        )
    }
}

struct RemoteAgentRow: View {
    let agent: RemoteAgent

    var body: some View {
        HStack {
            Circle()
                .fill(agent.status.color)
                .frame(width: 8, height: 8)

            Text(agent.name)
                .foregroundStyle(.white)

            Spacer()

            Text(agent.lastSeen)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

struct CronJobRow: View {
    let job: CronJob

    var body: some View {
        HStack {
            Text(job.name)
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(job.schedule)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(job.lastRun)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

struct StatusPill: View {
    let status: String

    var color: Color {
        status == "HEALTHY" ? .green : .orange
    }

    var body: some View {
        Text(status)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(8)
    }
}

// MARK: - Data Models

struct NodeStatus {
    var hostname: String = ""
    var profile: String = ""
    var uptime: String = ""
    var primaryProvider: String = ""
    var activeModel: String = ""
    var fallbackProvider: String = ""
    var cpuUsage: String = ""
    var memoryUsage: String = ""
    var diskUsage: String = ""
    var isHealthy: Bool = true
    var remoteAgents: [RemoteAgent] = []
    var activeCronJobs: [CronJob] = []
}

struct RemoteAgent: Identifiable {
    let id = UUID()
    let name: String
    var status: AgentStatus
    let lastSeen: String
}

enum AgentStatus {
    case online, offline, degraded

    var color: Color {
        switch self {
        case .online: return .green
        case .offline: return .red
        case .degraded: return .orange
        }
    }
}

struct CronJob: Identifiable {
    let id = UUID()
    let name: String
    let schedule: String
    let lastRun: String
}
