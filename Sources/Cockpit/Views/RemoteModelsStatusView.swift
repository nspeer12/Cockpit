import SwiftUI

struct RemoteModelsStatusView: View {
    @State private var macbookStatus: String = "Checking..."
    @State private var cyberbeastStatus: String = "Checking..."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Agents")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack {
                Circle()
                    .fill(macbookStatus.contains("Online") ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("MacBook Pro (Ollama)")
                Spacer()
                Text(macbookStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Circle()
                    .fill(cyberbeastStatus.contains("Online") ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("Cyberbeast (LM Studio)")
                Spacer()
                Text(cyberbeastStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            // Placeholder - will be replaced with real health check logic
            macbookStatus = "Online"
            cyberbeastStatus = "Offline"
        }
    }
}