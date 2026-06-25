import SwiftUI

/// Full inference control panel — local models, remote endpoints, real-time stats.
struct InferencePanelView: View {
    @StateObject private var mlxService = MLXService()
    @State private var localModels: [OllamaModel] = []
    @State private var remoteStatuses: [RemoteModelStatus] = RemoteModelEndpoint.defaults.map {
        RemoteModelStatus(endpoint: $0, state: .checking, detail: "Checking…")
    }
    @State private var loadedOllamaModel: String?
    @State private var inferenceResult: String = ""
    @State private var testPrompt: String = "Say hello in one short sentence."
    @State private var isRunningInference = false
    @State private var selectedSource: InferenceService.ModelSource = .ollamaLocal
    @State private var lastRefresh: Date?

    let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // MARK: - Header
                HStack {
                    Text("INFERENCE")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    // Health indicator
                    let allHealthy = mlxService.state != .error("") && remoteStatuses.allSatisfy { $0.state != .offline || $0.endpoint.id == "cyberbeast-lmstudio" }
                    StatusPill(status: allHealthy ? "ONLINE" : "DEGRADED")

                    Button(action: { Task { await refreshAll() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // MARK: - Local Inference Section
                InferencePanelSectionHeader(title: "LOCAL MODELS")
                    .padding(.horizontal, 40)

                HStack(alignment: .top, spacing: 20) {
                    // MLX Panel
                    MLXStatusCard(service: mlxService)
                        .frame(maxWidth: .infinity)

                    // Ollama Panel
                    OllamaStatusCard(
                        models: localModels,
                        loadedModel: loadedOllamaModel
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                // MARK: - Remote Models
                InferencePanelSectionHeader(title: "REMOTE ENDPOINTS")
                    .padding(.horizontal, 40)

                RemoteModelsStatusListView(statuses: remoteStatuses, lastRefresh: lastRefresh)
                    .padding(.horizontal, 40)

                // MARK: - Quick Inference Test
                InferencePanelSectionHeader(title: "QUICK TEST")
                    .padding(.horizontal, 40)

                QuickTestCard(
                    selectedSource: $selectedSource,
                    testPrompt: $testPrompt,
                    isRunningInference: $isRunningInference,
                    inferenceResult: $inferenceResult,
                    onRun: { Task { await runInferenceTest() } }
                )
                .padding(.horizontal, 40)

                Spacer().frame(height: 60)
            }
        }
        .onReceive(refreshTimer) { _ in
            Task { await refreshAll() }
        }
        .task {
            await refreshAll()
        }
    }

    // MARK: - Actions

    private func refreshAll() async {
        // Fetch Ollama models
        await fetchOllamaModels()

        // Check remote endpoints
        await checkRemoteEndpoints()

        // MLX GPU stats
        await mlxService.fetchGPUStats()

        lastRefresh = Date()
    }

    private func fetchOllamaModels() async {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                await MainActor.run {
                    localModels = models.compactMap { dict in
                        guard let name = dict["name"] as? String else { return nil }
                        let size = dict["size"] as? Int64 ?? 0
                        return OllamaModel(
                            name: name,
                            size: ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
                            modified: dict["modified_at"] as? String ?? ""
                        )
                    }
                }
            }
        } catch {}
    }

    private func checkRemoteEndpoints() async {
        var updated: [RemoteModelStatus] = []
        await withTaskGroup(of: RemoteModelStatus.self) { group in
            for endpoint in RemoteModelEndpoint.defaults {
                group.addTask {
                    await RemoteModelHealthChecker.check(endpoint)
                }
            }
            for await status in group {
                updated.append(status)
            }
        }
        await MainActor.run {
            remoteStatuses = updated.sorted { $0.endpoint.sortOrder < $1.endpoint.sortOrder }
        }
    }

    private func runInferenceTest() async {
        isRunningInference = true
        inferenceResult = ""

        let service = InferenceService()
        let result = await service.route(prompt: testPrompt, preferredSource: selectedSource)
        await MainActor.run {
            inferenceResult = result
            isRunningInference = false
        }
    }
}

// MARK: - MLX Status Card

struct MLXStatusCard: View {
    @ObservedObject var service: MLXService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "apple.intelligence")
                    .font(.title3)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple MLX")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Metal-accelerated local inference")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusIndicator
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            // State display
            VStack(alignment: .leading, spacing: 8) {
                switch service.state {
                case .stopped:
                    HStack {
                        Circle().fill(.secondary).frame(width: 6, height: 6)
                        Text("Not running")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {
                        Task { await service.startServer() }
                    }) {
                        Label("Start MLX Server", systemImage: "play.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(GlassButtonStyle())

                case .starting:
                    HStack {
                        ProgressView().scaleEffect(0.6)
                        Text("Starting server…")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }

                case .running(let model, let port, _):
                    HStack {
                        Circle().fill(.green).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(.green.opacity(0.3), lineWidth: 4))
                        Text("Running")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.green)
                    }

                    Text(model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Label("Port \(port)", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button(action: { service.stopServer() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(GlassButtonStyle())

                case .error(let msg):
                    HStack {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("Error")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                        .lineLimit(2)
                }
            }

            // GPU usage bar
            if case .running = service.state {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPU USAGE")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1.0)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * (service.gpuUsagePercent / 100.0), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(String(format: "%.0f%%", service.gpuUsagePercent))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 1.0).opacity(0.10), lineWidth: 1)
        )
    }

    private var statusIndicator: some View {
        Group {
            switch service.state {
            case .stopped:
                Circle()
                    .fill(.secondary)
                    .frame(width: 10, height: 10)
            case .starting:
                Circle()
                    .fill(.orange)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(.orange.opacity(0.3), lineWidth: 4)
                    )
            case .running:
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(.green.opacity(0.3), lineWidth: 4)
                    )
            case .error:
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Ollama Status Card

struct OllamaStatusCard: View {
    let models: [OllamaModel]
    let loadedModel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "llama")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ollama")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("llama.cpp runtime")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(.green.opacity(0.3), lineWidth: 4)
                    )
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Model list
            if models.isEmpty {
                Text("No models found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(models) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(model.size)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if model.name == loadedModel || true { // all local models are available
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Label("localhost:11434", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 1.0).opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Quick Test Card

struct QuickTestCard: View {
    @Binding var selectedSource: InferenceService.ModelSource
    @Binding var testPrompt: String
    @Binding var isRunningInference: Bool
    @Binding var inferenceResult: String
    var onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)

                Text("Inference Test")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Source picker
                Picker("Source", selection: $selectedSource) {
                    ForEach(InferenceService.ModelSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Prompt input
            TextField("Test prompt…", text: $testPrompt)
                .textFieldStyle(.plain)
                .font(.callout)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            // Run button
            HStack {
                Button(action: onRun) {
                    Label(
                        isRunningInference ? "Running…" : "Run Inference",
                        systemImage: isRunningInference ? "hourglass" : "play.fill"
                    )
                    .font(.callout.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(isRunningInference)

                Spacer()
            }

            // Result
            if !inferenceResult.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))

                ScrollView {
                    Text(inferenceResult)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 1.0).opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Section Header

struct InferencePanelSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(1.4)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Remote Models View (parameterized)

struct RemoteModelsStatusListView: View {
    let statuses: [RemoteModelStatus]
    let lastRefresh: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(statuses) { status in
                HStack(spacing: 10) {
                    Circle()
                        .fill(status.state.color)
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle()
                                .stroke(status.state.color.opacity(0.35), lineWidth: 4)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.endpoint.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(status.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(status.state.label)
                        .font(.caption.bold())
                        .foregroundStyle(status.state.color)
                }
                .padding(12)
                .background(Color.white.opacity(0.045))
                .cornerRadius(12)
            }

            if let lastRefresh {
                Text("Updated \(lastRefresh, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.75))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 1.0).opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Data Models

struct OllamaModel: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let modified: String
}
