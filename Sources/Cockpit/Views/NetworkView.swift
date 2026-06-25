import SwiftUI
import Foundation

struct NetworkView: View {
    @State private var devices: [NetworkDevice] = []
    @State private var isScanning = false
    @State private var lastScan: Date?
    @State private var speedTestResult: NetworkQualityResult?
    @State private var speedTestHistory: [NetworkQualityHistoryEntry] = []
    @State private var isRunningSpeedTest = false
    @State private var speedTestError: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    let knownDevices: [NetworkDevice] = [
        NetworkDevice(name: "Mac Mini", hostname: "Nicks-Mac-mini.local", ip: "192.168.1.32", role: "Primary Server"),
        NetworkDevice(name: "MacBook Pro", hostname: "macbook-pro-5.sparrow-iguana.ts.net", ip: "100.81.207.26", role: "Work Machine"),
        NetworkDevice(name: "Cyberbeast", hostname: "cyberbeast.local", ip: "192.168.1.19", role: "Heavy Inference"),
        NetworkDevice(name: "Tailscale DNS", hostname: "100.100.100.100", ip: "100.100.100.100", role: "VPN Control Plane")
    ]
    
    var body: some View {
        // For compact width (like iPhone), use vertical scroll
        // For regular width, use the original layout
        if horizontalSizeClass == .compact && verticalSizeClass == .regular {
            compactNetworkView
        } else {
            regularNetworkView
        }
    }
    
    private var compactNetworkView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                
                SpeedTestPanel(
                    result: speedTestResult,
                    history: speedTestHistory,
                    isRunning: isRunningSpeedTest,
                    errorMessage: speedTestError,
                    runAction: {
                        Task { await runSpeedTest() }
                    }
                )
                
                SectionHeader(title: "NETWORK DEVICES", subtitle: "LAN + Tailnet reachability")
                
                LazyVStack(spacing: 12) {
                    ForEach(devices.isEmpty ? knownDevices : devices) { device in
                        NetworkDeviceCard(device: device)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .onAppear {
            if devices.isEmpty {
                devices = knownDevices
            }
        }
    }
    
    private var regularNetworkView: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    SpeedTestPanel(
                        result: speedTestResult,
                        history: speedTestHistory,
                        isRunning: isRunningSpeedTest,
                        errorMessage: speedTestError,
                        runAction: {
                            Task { await runSpeedTest() }
                        }
                    )
                    
                    SectionHeader(title: "NETWORK DEVICES", subtitle: "LAN + Tailnet reachability")
                    
                    ForEach(devices.isEmpty ? knownDevices : devices) { device in
                        NetworkDeviceCard(device: device)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            if devices.isEmpty {
                devices = knownDevices
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 4 : 8) {
                Text("NETWORK")
                    .font(.system(size: horizontalSizeClass == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Speed tests, device reachability, and Tailnet status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let lastScan = lastScan {
                Text("Last scan: \(lastScan, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button(action: scanNetwork) {
                HStack(spacing: horizontalSizeClass == .compact ? 4 : 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(isScanning ? "Scanning..." : "Scan")
                }
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(isScanning)
        }
        .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 40)
        .padding(.vertical, horizontalSizeClass == .compact ? 16 : 30)
    }
    
    private func scanNetwork() {
        isScanning = true
        
        Task {
            var updatedDevices: [NetworkDevice] = []
            
            for device in knownDevices {
                let isOnline = await pingHost(device.pingTarget)
                
                var updated = device
                updated.isOnline = isOnline
                updated.lastSeen = isOnline ? Date() : device.lastSeen
                updatedDevices.append(updated)
            }
            
            await MainActor.run {
                self.devices = updatedDevices
                self.lastScan = Date()
                self.isScanning = false
            }
        }
    }
    
    @MainActor
    private func runSpeedTest() async {
        guard !isRunningSpeedTest else { return }
        isRunningSpeedTest = true
        speedTestError = nil
        
        do {
            let result = try await NetworkQualityService.run()
            speedTestResult = result
            speedTestHistory.insert(NetworkQualityHistoryEntry(date: Date(), result: result), at: 0)
            if speedTestHistory.count > 5 {
                speedTestHistory = Array(speedTestHistory.prefix(5))
            }
        } catch {
            speedTestError = error.localizedDescription
        }
        
        isRunningSpeedTest = false
    }
    
    private func pingHost(_ host: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "2000", host]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Views (NetworkQualityHistoryEntry, NetworkDevice, etc.)

struct NetworkQualityHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let result: NetworkQualityResult
}

struct NetworkDevice: Identifiable {
    let id: String
    let name: String
    let hostname: String
    let ip: String
    let role: String
    var isOnline: Bool
    var lastSeen: Date?
    
    init(name: String, hostname: String, ip: String, role: String, isOnline: Bool = false, lastSeen: Date? = nil) {
        self.id = "\(name)-\(hostname)-\(ip)"
        self.name = name
        self.hostname = hostname
        self.ip = ip
        self.role = role
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
    
    var pingTarget: String {
        ip.isEmpty ? hostname : ip
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.7))
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct SpeedTestPanel: View {
    let result: NetworkQualityResult?
    let history: [NetworkQualityHistoryEntry]
    let isRunning: Bool
    let errorMessage: String?
    let runAction: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 12 : 18) {
            HStack {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 2 : 4) {
                    Text("SPEED TEST")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                    Text("Apple networkQuality benchmark")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button(action: runAction) {
                    HStack(spacing: horizontalSizeClass == .compact ? 4 : 8) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.circle.fill")
                        }
                        Text(isRunning ? "Running..." : "Run Speed Test")
                    }
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(isRunning)
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(horizontalSizeClass == .compact ? 8 : 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.10))
                    .cornerRadius(10)
            }
            
            if let result {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 120 : 150), spacing: horizontalSizeClass == .compact ? 8 : 12)], spacing: horizontalSizeClass == .compact ? 8 : 12) {
                    SpeedMetricTile(title: "Download", value: formatMbps(result.downlinkMbps), icon: "arrow.down.circle.fill", tint: .cyan)
                    SpeedMetricTile(title: "Upload", value: formatMbps(result.uplinkMbps), icon: "arrow.up.circle.fill", tint: .purple)
                    SpeedMetricTile(title: "Latency", value: formatMilliseconds(result.idleLatencyMilliseconds), icon: "timer", tint: .green)
                    SpeedMetricTile(title: "Responsiveness", value: result.responsiveness ?? "—", icon: "waveform.path.ecg", tint: responsivenessColor(result.responsiveness))
                }
                
                HStack(spacing: 14) {
                    Label(result.interfaceName ?? "Interface unknown", systemImage: "antenna.radiowaves.left.and.right")
                    if let endpoint = result.testEndpoint {
                        Label(endpoint, systemImage: "point.3.connected.trianglepath.dotted")
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                Text("No speed test captured yet. Run a benchmark to populate live bandwidth, latency, and responsiveness metrics.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 4 : 8) {
                    Text("RECENT RUNS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    ForEach(history) { entry in
                        HStack {
                            Text(entry.date, style: .time)
                                .frame(width: horizontalSizeClass == .compact ? 50 : 72, alignment: .leading)
                            Text("↓ \(formatMbps(entry.result.downlinkMbps))")
                            Text("↑ \(formatMbps(entry.result.uplinkMbps))")
                            Spacer()
                            Text(entry.result.responsiveness ?? "—")
                                .foregroundStyle(responsivenessColor(entry.result.responsiveness))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(horizontalSizeClass == .compact ? 12 : 20)
        .background(.ultraThinMaterial)
        .cornerRadius(horizontalSizeClass == .compact ? 12 : 18)
        .overlay(
            RoundedRectangle(cornerRadius: horizontalSizeClass == .compact ? 12 : 18)
                .stroke(Color.cyan.opacity(result == nil ? 0.12 : 0.35), lineWidth: 1)
        )
    }
    
    private func formatMbps(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value)) Mbps"
    }
    
    private func formatMilliseconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value)) ms"
    }
    
    private func responsivenessColor(_ label: String?) -> Color {
        switch label?.lowercased() {
        case "high": return .green
        case "medium": return .orange
        case "low": return .red
        default: return .secondary
        }
    }
}

struct SpeedMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 6 : 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: horizontalSizeClass == .compact ? 20 : 28)
            
            VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 2 : 3) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: horizontalSizeClass == .compact ? 12 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            
            Spacer(minLength: 0)
        }
        .padding(horizontalSizeClass == .compact ? 8 : 14)
        .background(Color.white.opacity(0.045))
        .cornerRadius(horizontalSizeClass == .compact ? 8 : 14)
    }
}

struct NetworkDeviceCard: View {
    let device: NetworkDevice
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 12 : 20) {
            Circle()
                .fill(device.isOnline ? Color.green : Color.red)
                .frame(width: horizontalSizeClass == .compact ? 8 : 12, height: horizontalSizeClass == .compact ? 8 : 12)
                .overlay(
                    Circle()
                        .stroke(device.isOnline ? Color.green.opacity(0.4) : Color.red.opacity(0.4), lineWidth: horizontalSizeClass == .compact ? 2 : 4)
                        .frame(width: horizontalSizeClass == .compact ? 12 : 20, height: horizontalSizeClass == .compact ? 12 : 20)
                )
            
            VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 2 : 4) {
                HStack {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(device.role)
                        .font(.caption2)
                        .padding(.horizontal, horizontalSizeClass == .compact ? 4 : 8)
                        .padding(.vertical, horizontalSizeClass == .compact ? 2 : 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
                
                Text(device.hostname)
                    .font(.system(size: horizontalSizeClass == .compact ? 10 : 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                if !device.ip.isEmpty {
                    Text(device.ip)
                        .font(.system(size: horizontalSizeClass == .compact ? 9 : 11, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: horizontalSizeClass == .compact ? 1 : 2) {
                Text(device.isOnline ? "ONLINE" : "OFFLINE")
                    .font(.caption.bold())
                    .foregroundStyle(device.isOnline ? .green : .red)
                
                if let lastSeen = device.lastSeen {
                    Text(lastSeen, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(horizontalSizeClass == .compact ? 10 : 18)
        .background(.ultraThinMaterial)
        .cornerRadius(horizontalSizeClass == .compact ? 8 : 14)
        .overlay(
            RoundedRectangle(cornerRadius: horizontalSizeClass == .compact ? 8 : 14)
                .stroke(device.isOnline ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
