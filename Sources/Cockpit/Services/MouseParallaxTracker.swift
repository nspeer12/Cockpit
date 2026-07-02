import SwiftUI
import AppKit

// MARK: - Mouse Parallax Tracker

@MainActor
final class MouseParallaxTracker {
    static let shared = MouseParallaxTracker()

    var onMove: ((CGPoint) -> Void)?
    private var monitor: Any?
    private let sensitivity: CGFloat = 0.01

    private init() {}

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self = self, let window = NSApp.keyWindow else { return event }

            let mouseInWindow = event.locationInWindow
            let windowSize = window.frame.size

            // Convert to normalized coordinates (-1...1)
            let nx = (mouseInWindow.x / windowSize.width - 0.5) * 2.0
            let ny = (mouseInWindow.y / windowSize.height - 0.5) * 2.0

            // Clamp
            let rx = min(1.0, max(-1.0, nx))
            let ry = min(1.0, max(-1.0, ny))

            DispatchQueue.main.async {
                self.onMove?(CGPoint(x: rx, y: ry))
            }

            return event
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}