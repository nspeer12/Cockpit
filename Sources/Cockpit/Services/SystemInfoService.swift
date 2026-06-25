import Foundation

/// Real macOS system information — hostname, CPU, memory, disk, uptime.
enum SystemInfoService {

    // MARK: - Hostname

    static func hostname() -> String {
        var name = [CChar](repeating: 0, count: 256)
        guard gethostname(&name, 256) == 0 else { return "unknown" }
        let str = String(decoding: name.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return str.components(separatedBy: "\0").first ?? "unknown"
    }

    // MARK: - Uptime

    static func uptimeString() -> String {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else {
            return "unknown"
        }

        let bootTimestamp = TimeInterval(boottime.tv_sec)
        let uptime = Date().timeIntervalSince1970 - bootTimestamp

        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - CPU

    static func cpuUsagePercent() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let total = user + system + idle + nice

        guard total > 0 else { return 0 }
        return ((user + system + nice) / total) * 100.0
    }

    // MARK: - Memory

    static func memoryUsage() -> (usedGB: Double, totalGB: Double, percentUsed: Double) {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0, 0) }

        let pageSize = Double(sysconf(Int32(_SC_PAGESIZE)))
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalBytes / 1_073_741_824.0

        let activePages = Double(info.active_count)
        let wirePages = Double(info.wire_count)
        let compressedPages = Double(info.compressor_page_count)

        let usedPages = activePages + wirePages + compressedPages
        let usedGB = (usedPages * pageSize) / 1_073_741_824.0
        let percentUsed = (usedGB / totalGB) * 100.0

        return (usedGB, totalGB, percentUsed)
    }

    // MARK: - Disk

    static func diskUsage() -> (usedGB: Double, totalGB: Double, percentUsed: Double) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let totalSize = attrs[.systemSize] as? Int64,
              let freeSize = attrs[.systemFreeSize] as? Int64 else {
            return (0, 0, 0)
        }

        let totalGB = Double(totalSize) / 1_073_741_824.0
        let freeGB = Double(freeSize) / 1_073_741_824.0
        let usedGB = totalGB - freeGB
        let percentUsed = (usedGB / totalGB) * 100.0

        return (usedGB, totalGB, percentUsed)
    }

    // MARK: - Active Model (from Hermes config)

    static func activeModel() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "config", "get", "model"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let data = try (process.standardOutput as? Pipe)?.fileHandleForReading.readToEnd(),
                  let model = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !model.isEmpty else {
                return "unknown"
            }
            return model
        } catch {
            return "unavailable"
        }
    }

    static func activeProvider() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "config", "get", "provider"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let data = try (process.standardOutput as? Pipe)?.fileHandleForReading.readToEnd(),
                  let provider = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !provider.isEmpty else {
                return "unknown"
            }
            return provider
        } catch {
            return "unavailable"
        }
    }
}
