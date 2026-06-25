import SwiftUI
import Foundation

struct RemoteModelsStatusView: View {
    @State private var statuses: [RemoteModelStatus] = RemoteModelEndpoint.defaults.map {
        RemoteModelStatus(endpoint: $0, state: .checking, detail: "Checking…")
    }
    @State private var lastRefresh: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("REMOTE MODELS")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .tracking(1.4)
                    Text("MacBook Ollama + Cyberbeast LM Studio")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: { Task { await refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(GlassButtonStyle())
            }

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
        .task {
            await refresh()
        }
    }

    @MainActor
    private func refresh() async {
        statuses = statuses.map { RemoteModelStatus(endpoint: $0.endpoint, state: .checking, detail: "Checking…") }

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

        statuses = updated.sorted { $0.endpoint.sortOrder < $1.endpoint.sortOrder }
        lastRefresh = Date()
    }
}

struct RemoteModelEndpoint: Identifiable, Equatable {
    let id: String
    let name: String
    let provider: String
    let url: URL
    let sortOrder: Int

    static let defaults: [RemoteModelEndpoint] = [
        RemoteModelEndpoint(
            id: "macbook-ollama",
            name: "MacBook Pro",
            provider: "Ollama",
            url: URL(string: "http://macbook-pro-5.sparrow-iguana.ts.net:11434/api/tags")!,
            sortOrder: 0
        ),
        RemoteModelEndpoint(
            id: "cyberbeast-lmstudio",
            name: "Cyberbeast",
            provider: "LM Studio",
            url: URL(string: "http://cyberbeast.local:1234/v1/models")!,
            sortOrder: 1
        )
    ]
}

struct RemoteModelStatus: Identifiable, Equatable {
    let id: String
    let endpoint: RemoteModelEndpoint
    let state: RemoteModelConnectionState
    let detail: String

    init(endpoint: RemoteModelEndpoint, state: RemoteModelConnectionState, detail: String) {
        self.id = endpoint.id
        self.endpoint = endpoint
        self.state = state
        self.detail = detail
    }
}

enum RemoteModelConnectionState: Equatable {
    case checking
    case online
    case offline

    var label: String {
        switch self {
        case .checking: return "CHECKING"
        case .online: return "ONLINE"
        case .offline: return "OFFLINE"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .orange
        case .online: return .green
        case .offline: return .red
        }
    }
}

enum RemoteModelHealthChecker {
    static func check(_ endpoint: RemoteModelEndpoint) async -> RemoteModelStatus {
        var request = URLRequest(url: endpoint.url)
        request.timeoutInterval = 2.5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return RemoteModelStatus(endpoint: endpoint, state: .offline, detail: "No HTTP response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                return RemoteModelStatus(endpoint: endpoint, state: .offline, detail: "HTTP \(httpResponse.statusCode)")
            }

            let modelCount = extractModelCount(from: data)
            let detail = modelCount.map { "\(endpoint.provider) reachable · \($0) models" } ?? "\(endpoint.provider) reachable"
            return RemoteModelStatus(endpoint: endpoint, state: .online, detail: detail)
        } catch {
            return RemoteModelStatus(endpoint: endpoint, state: .offline, detail: error.localizedDescription)
        }
    }

    private static func extractModelCount(from data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let models = object["models"] as? [Any] {
            return models.count
        }

        if let data = object["data"] as? [Any] {
            return data.count
        }

        return nil
    }
}
