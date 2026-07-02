import SwiftUI

// MARK: - Live Event

struct LiveEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let type: EventType

    enum EventType {
        case info, warning, error, success
        var color: Color {
            switch self {
            case .info: return .cyan
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
        var icon: String {
            switch self {
            case .info: return "circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
}

// MARK: - Live Event Feed

struct LiveEventFeed: View {
    let events: [LiveEvent]

    var body: some View {
        if events.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("AWAITING EVENTS...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(events.prefix(20).enumerated()), id: \.element.id) { index, event in
                        EventRow(event: event)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
            }
            .defaultScrollAnchor(.top)
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: LiveEvent

    var body: some View {
        HStack(spacing: 8) {
            // Left color border indicator
            RoundedRectangle(cornerRadius: 1)
                .fill(event.type.color)
                .frame(width: 2, height: 24)

            Image(systemName: event.type.icon)
                .font(.system(size: 8))
                .foregroundStyle(event.type.color)

            Text(event.text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Text(event.timestamp, style: .time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(event.type.color.opacity(0.05))
        .cornerRadius(4)
    }
}