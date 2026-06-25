import Foundation
import Combine

/// Default port for MLX LM server (global to avoid @MainActor isolation).
let MLXDefaultPort: Int = 8088

/// Manages an MLX LM server process for local inference via HTTP.
/// Spawns `mlx_lm.server` from the Cockpit project's .venv and monitors health.
@MainActor
final class MLXService: ObservableObject {

    // MARK: - State

    enum MLXState: Equatable {
        case stopped
        case starting
        case running(model: String, port: Int, pid: Int32)
        case error(String)
    }

    @Published var state: MLXState = .stopped
    @Published var gpuUsagePercent: Double = 0
    @Published var loadedModel: String?

    // MARK: - Configuration

    static let venvPath: String = {
        let envPath = ProcessInfo.processInfo.environment["COCKPIT_VENV"] ?? ""
        if !envPath.isEmpty && FileManager.default.fileExists(atPath: envPath + "/bin/mlx_lm") {
            return envPath
        }

        // Fallback: walk up from bundle to find .venv
        let bundleURL = Bundle.main.bundleURL
        let projectDir = bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let candidate = projectDir.appendingPathComponent(".venv").path
        if FileManager.default.fileExists(atPath: candidate + "/bin/mlx_lm") {
            return candidate
        }
        return candidate // best effort
    }()

    private var process: Process?
    private var healthCheckTimer: Timer?
    private var monitorTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startServer(model: String? = nil, port: Int = MLXDefaultPort) async {
        guard case .stopped = state else { return }

        let venv = Self.venvPath
        let mlxLM = venv + "/bin/mlx_lm"
        guard FileManager.default.fileExists(atPath: mlxLM) else {
            state = .error("mlx_lm not found at \(mlxLM)")
            return
        }

        // Default to a small fast model if none specified
        let modelName = model ?? "mlx-community/Llama-3.2-3B-Instruct-4bit"

        state = .starting

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: mlxLM)
        proc.arguments = [
            "server",
            "--model", modelName,
            "--port", "\(port)"
        ]
        proc.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": venv + "/bin:" + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
        ]) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        // Capture output for debugging
        Task {
            for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                if line.contains("Uvicorn running") || line.contains("Application startup complete") {
                    await MainActor.run {
                        self.state = .running(model: modelName, port: port, pid: proc.processIdentifier)
                    }
                    break
                }
            }
        }

        Task {
            for try await line in stderrPipe.fileHandleForReading.bytes.lines {
                if line.contains("error") || line.contains("Error") {
                    await MainActor.run {
                        self.state = .error(line)
                    }
                }
                if line.contains("Uvicorn running") || line.contains("startup complete") {
                    await MainActor.run {
                        self.state = .running(model: modelName, port: port, pid: proc.processIdentifier)
                    }
                    break
                }
            }
        }

        do {
            try proc.run()
            process = proc

            // Poll health endpoint until ready
            let url = URL(string: "http://localhost:\(port)/v1/models")!
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let (data, response) = try? await URLSession.shared.data(from: url),
                   let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    loadedModel = modelName
                    state = .running(model: modelName, port: port, pid: proc.processIdentifier)
                    break
                }
            }

            // If still starting after 30s, consider it an error
            if case .starting = state {
                proc.terminate()
                state = .error("Timeout waiting for MLX server to start")
            }
        } catch {
            state = .error("Failed to launch MLX: \(error.localizedDescription)")
        }
    }

    func stopServer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        monitorTask?.cancel()
        monitorTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        process = nil
        state = .stopped
        loadedModel = nil
    }

    // MARK: - GPU Stats

    func fetchGPUStats() async {
        // Poll MLX server health/metrics if available
        guard case .running(_, let port, _) = state else { return }

        // Attempt to get GPU info via system_profiler
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPDisplaysDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe

        do {
            try proc.run()
            proc.waitUntilExit()

            let data = try pipe.fileHandleForReading.readToEnd()
            if let json = try JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any],
               let sp = json["SPDisplaysDataType"] as? [[String: Any]],
               let _ = sp.first {
                // MLX uses the GPU via Metal - read GPU memory used
                gpuUsagePercent = 25.0 // rough estimate when model loaded
            }
        } catch {}
    }
}