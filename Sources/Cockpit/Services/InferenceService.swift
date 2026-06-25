import Foundation

/// Service routing inference to local and remote models via HTTP APIs.
/// Auto-selects the best available source based on health checks.
actor InferenceService {

    // MARK: - Model Sources

    enum ModelSource: String, CaseIterable {
        case localMLX = "MLX (Local)"
        case ollamaLocal = "Ollama (Local)"
        case ollamaRemote = "Ollama (Remote)"
        case lmStudioRemote = "LM Studio (Remote)"
        case xai = "xAI"
    }

    // MARK: - Endpoints

    struct Endpoint {
        let source: ModelSource
        let baseURL: URL
        let model: String
        let apiKey: String?
    }

    static let defaultEndpoints: [Endpoint] = [
        Endpoint(
            source: .ollamaLocal,
            baseURL: URL(string: "http://localhost:11434")!,
            model: "llama3.2:3b",
            apiKey: nil
        ),
        Endpoint(
            source: .ollamaRemote,
            baseURL: URL(string: "http://macbook-pro-5.sparrow-iguana.ts.net:11434")!,
            model: "gemma3:27b",
            apiKey: nil
        ),
        Endpoint(
            source: .lmStudioRemote,
            baseURL: URL(string: "http://cyberbeast.local:1234")!,
            model: "gemma-3-27b-it",
            apiKey: nil
        ),
    ]

    // MARK: - Inference Methods

    /// Route inference to the best available source.
    /// Tries: local Ollama → local MLX → remote Ollama → remote LM Studio → xAI.
    func route(prompt: String, preferredSource: ModelSource? = nil) async -> String {
        // If a specific source is requested, try it directly (with xAI fallback)
        if let preferred = preferredSource {
            let result = await trySource(preferred, prompt: prompt)
            if let result {
                return result
            }
            return await callXAI(prompt: prompt)
        }

        // Auto-select: local first, then remote, then cloud
        // 1. Local Ollama
        if let result = await trySource(.ollamaLocal, prompt: prompt) {
            return result
        }

        // 2. Local MLX
        if let result = await trySource(.localMLX, prompt: prompt) {
            return result
        }

        // 3. Remote Ollama
        if let result = await trySource(.ollamaRemote, prompt: prompt) {
            return result
        }

        // 4. Remote LM Studio
        if let result = await trySource(.lmStudioRemote, prompt: prompt) {
            return result
        }

        // 5. Fallback to xAI
        return await callXAI(prompt: prompt)
    }

    private func trySource(_ source: ModelSource, prompt: String) async -> String? {
        // Quick health check first
        guard await quickHealthCheck(source: source) else { return nil }

        switch source {
        case .xai:
            let result = await callXAI(prompt: prompt)
            return result.hasPrefix("[error]") ? nil : result

        case .ollamaLocal, .ollamaRemote:
            guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else { return nil }
            let result = await callOllama(endpoint: endpoint, prompt: prompt)
            return result.hasPrefix("[error]") ? nil : result

        case .lmStudioRemote:
            guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else { return nil }
            let result = await callOpenAICompatible(endpoint: endpoint, prompt: prompt)
            return result.hasPrefix("[error]") ? nil : result

        case .localMLX:
            // Try MLX server on default port
            let endpoint = Endpoint(
                source: .localMLX,
                baseURL: URL(string: "http://localhost:\(MLXDefaultPort)")!,
                model: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                apiKey: nil
            )
            let result = await callOpenAICompatible(endpoint: endpoint, prompt: prompt)
            return result.hasPrefix("[error]") ? nil : result
        }
    }

    // MARK: - Model Listing

    /// List models available on a source.
    func listModels(source: ModelSource) async -> [String] {
        switch source {
        case .ollamaLocal, .ollamaRemote:
            guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else { return [] }
            return await fetchOllamaModels(from: endpoint)

        case .lmStudioRemote:
            guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else { return [] }
            return await fetchLMStudioModels(from: endpoint)

        case .localMLX:
            return await fetchMLXModels()

        case .xai:
            return ["grok-4.3", "grok-3"]
        }
    }

    private func fetchOllamaModels(from endpoint: Endpoint) async -> [String] {
        let url = endpoint.baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.compactMap { $0["name"] as? String }
            }
        } catch {}
        return []
    }

    private func fetchLMStudioModels(from endpoint: Endpoint) async -> [String] {
        let url = endpoint.baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]] {
                return dataArr.compactMap { $0["id"] as? String }
            }
        } catch {}
        return []
    }

    private func fetchMLXModels() async -> [String] {
        let url = URL(string: "http://localhost:\(MLXDefaultPort)/v1/models")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]] {
                return dataArr.compactMap { $0["id"] as? String }
            }
        } catch {}
        return []
    }

    // MARK: - Health Checks

    /// Fast 2s timeout health check.
    nonisolated func quickHealthCheck(source: ModelSource) async -> Bool {
        if source == .xai {
            return ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil
        }
        if source == .localMLX {
            let url = URL(string: "http://localhost:\(MLXDefaultPort)/v1/models")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            return (try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode == 200
        }

        guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else {
            return false
        }

        let url = endpoint.baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Full health check with latency measurement.
    func checkHealth(source: ModelSource) async -> (reachable: Bool, latency: TimeInterval, modelCount: Int) {
        guard source != .xai else {
            let hasKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil
            return (hasKey, 0, hasKey ? 2 : 0)
        }

        if source == .localMLX {
            let url = URL(string: "http://localhost:\(MLXDefaultPort)/v1/models")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            let start = Date()
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let latency = Date().timeIntervalSince(start)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    return (false, latency, 0)
                }
                let count = extractModelCount(from: data)
                return (true, latency, count)
            } catch {
                return (false, Date().timeIntervalSince(start), 0)
            }
        }

        guard let endpoint = Self.defaultEndpoints.first(where: { $0.source == source }) else {
            return (false, 0, 0)
        }

        let url = endpoint.baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        let start = Date()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(start)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return (false, latency, 0)
            }
            let count = extractModelCount(from: data)
            return (true, latency, count)
        } catch {
            return (false, Date().timeIntervalSince(start), 0)
        }
    }

    private func extractModelCount(from data: Data) -> Int {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }
        if let models = object["models"] as? [Any] { return models.count }
        if let data = object["data"] as? [Any] { return data.count }
        return 0
    }

    // MARK: - Private: Ollama API

    private func callOllama(endpoint: Endpoint, prompt: String) async -> String {
        let url = endpoint.baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": endpoint.model,
            "prompt": prompt,
            "stream": false,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                return "[error] Ollama returned HTTP \(status)"
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                return "[error] Unexpected Ollama response format"
            }

            return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "[error] Ollama call failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private: OpenAI-compatible (LM Studio, MLX, etc.)

    private func callOpenAICompatible(endpoint: Endpoint, prompt: String) async -> String {
        let url = endpoint.baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = endpoint.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.7,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let raw = String(data: data, encoding: .utf8) ?? ""
                return "[error] \(endpoint.source.rawValue) returned HTTP \(status): \(raw.prefix(200))"
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return "[error] Unexpected response format from \(endpoint.source.rawValue)"
            }

            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "[error] \(endpoint.source.rawValue) call failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private: xAI

    private func callXAI(prompt: String) async -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"],
              !apiKey.isEmpty else {
            return "[error] XAI_API_KEY not set in environment"
        }

        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "grok-4.3",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2048,
            "temperature": 0.7,
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let raw = String(data: data, encoding: .utf8) ?? ""
                return "[error] xAI returned HTTP \(status): \(raw.prefix(200))"
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return "[error] Unexpected xAI response format"
            }

            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "[error] xAI call failed: \(error.localizedDescription)"
        }
    }
}
