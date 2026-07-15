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
    @State private var testPrompt: String = "Introduce yourself as NEO in one short sentence."
    @State private var isRunningInference = false
    @State private var selectedSource: InferenceService.ModelSource = .ollamaLocal
    @State private var lastRefresh: Date?
    // New streaming + conversation
    @State private var conversation: [ChatMessage] = []
    @State private var tokenCount: Int = 0
    @State private var useStreaming = true
    @State private var systemPrompt: String = NEOIdentity.systemPrompt
    @State private var temperature: Double = 0.7

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
                InferencePanelSectionHeader(title: "CONVERSATION")
                    .padding(.horizontal, 40)

                ConversationView(
                    messages: conversation,
                    systemPrompt: $systemPrompt,
                    temperature: $temperature,
                    useStreaming: $useStreaming,
                    selectedSource: $selectedSource,
                    testPrompt: $testPrompt,
                    localModels: localModels,
                    isRunningInference: $isRunningInference,
                    tokenCount: $tokenCount,
                    onSend: { Task { await runStreamingInference() } },
                    onClear: { conversation.removeAll(); tokenCount = 0; inferenceResult = "" }
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

    private func runStreamingInference() async {
        isRunningInference = true
        inferenceResult = ""
        tokenCount = 0

        let service = InferenceService()
        let userMsg = ChatMessage(role: "user", content: testPrompt)
        await MainActor.run { conversation.append(userMsg) }
        let prompt = testPrompt
        testPrompt = ""

        // Get the endpoint for selected source
        guard let endpoint = InferenceService.defaultEndpoints.first(where: { $0.source == selectedSource }) else {
            await MainActor.run {
                conversation.append(ChatMessage(role: "assistant", content: "[error] No endpoint configured for this source"))
                isRunningInference = false
            }
            return
        }

        var fullResponse = ""
        let stream = service.streamOllama(endpoint: endpoint, prompt: prompt, systemPrompt: systemPrompt)

        for await token in stream {
            fullResponse += token
            tokenCount += 1
            await MainActor.run {
                // Update the last assistant message in place
                if conversation.last?.role == "assistant" {
                    conversation[conversation.count - 1] = ChatMessage(role: "assistant", content: fullResponse)
                } else {
                    conversation.append(ChatMessage(role: "assistant", content: fullResponse))
                }
            }
        }

        await MainActor.run {
            inferenceResult = fullResponse
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

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let content: String
}

// MARK: - Conversation View

struct ConversationView: View {
    let messages: [ChatMessage]
    @Binding var systemPrompt: String
    @Binding var temperature: Double
    @Binding var useStreaming: Bool
    @Binding var selectedSource: InferenceService.ModelSource
    @Binding var testPrompt: String
    let localModels: [OllamaModel]
    @Binding var isRunningInference: Bool
    @Binding var tokenCount: Int
    var onSend: () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Controls row
            HStack(spacing: 12) {
                // System prompt
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYSTEM")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    TextField("System prompt…", text: $systemPrompt)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }

                // Temperature
                VStack(alignment: .leading, spacing: 4) {
                    Text("TEMP: \(String(format: "%.1f", temperature))")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                        .tint(.cyan)
                }

                // Token count
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TOKENS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Text("\(tokenCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.cyan)
                }
            }

            // Conversation messages
            ConversationMessagesList(
                messages: messages,
                isRunningInference: isRunningInference
            )
            .frame(maxHeight: 200)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Prompt input row
            HStack(spacing: 8) {
                // Source picker
                Picker("", selection: $selectedSource) {
                    ForEach(InferenceService.ModelSource.allCases, id: \.self) { src in
                        Text(src.rawValue).tag(src)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)

                TextField("Message…", text: $testPrompt)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .onSubmit { if !isRunningInference { onSend() } }

                Button(action: onSend) {
                    Image(systemName: isRunningInference ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isRunningInference ? Color.secondary : Color.cyan)
                }
                .disabled(isRunningInference)
                .buttonStyle(PlainButtonStyle())

                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(messages.isEmpty)
                .buttonStyle(PlainButtonStyle())
            }

            // Status
            if !messages.isEmpty {
                HStack {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text("\(messages.count) messages · \(tokenCount) tokens")
                        .font(.caption2)
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
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == "user" ? "person.circle.fill" : "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(message.role == "user" ? .cyan : .purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.role.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(message.role == "user" ? .cyan : .purple)

                Text(message.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(message.role == "user" ? Color.cyan.opacity(0.06) : Color.purple.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(message.role == "user" ? Color.cyan.opacity(0.12) : Color.purple.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Empty Conversation Prompt

struct EmptyConversationPrompt: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.3))
            Text("Start a conversation")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Running Indicator

struct RunningIndicator: View {
    var body: some View {
        HStack {
            ProgressView().scaleEffect(0.6)
            Text("Generating…").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Conversation Messages List

struct ConversationMessagesList: View {
    let messages: [ChatMessage]
    let isRunningInference: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if isRunningInference {
                        RunningIndicator()
                    }
                    if messages.isEmpty {
                        EmptyConversationPrompt()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }
                }
                .padding(8)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}
