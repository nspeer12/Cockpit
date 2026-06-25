import SwiftUI
import AppKit

@main
struct CockpitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var ambient = AmbientAwarenessManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ambient)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Tab switching hotkeys
            CommandMenu("Navigation") {
                Button("Overview")        { selectTab(.overview) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Inference")       { selectTab(.inference) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Projects")        { selectTab(.projects) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Network")         { selectTab(.network) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Node")            { selectTab(.node) }
                    .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("Toggle 3D Background") { toggle3DBackground() }
                    .keyboardShortcut("B", modifiers: [.command, .shift])
                Button("Toggle JARVIS")         { toggleJarvis() }
                    .keyboardShortcut("J", modifiers: [.command, .shift])
            }
        }
    }

    private func selectTab(_ tab: ContentView.Tab) {
        // Post notification that ContentView listens for
        NotificationCenter.default.post(name: .cockpitSelectTab, object: tab)
    }

    private func toggle3DBackground() {
        NotificationCenter.default.post(name: .cockpitToggle3D, object: nil)
    }

    private func toggleJarvis() {
        NotificationCenter.default.post(name: .cockpitToggleJarvis, object: nil)
    }
}

// MARK: - App Delegate (Menu Bar Extra)

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            setupMenuBar()
        }
    }

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "◈"
            button.toolTip = "Cockpit — Local Inference Status"
        }

        let menu = NSMenu()

        // Model status items
        let modelItem = NSMenuItem(title: "Model: llama3.2:3b (Ollama)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        let mlxItem = NSMenuItem(title: "MLX: not running", action: nil, keyEquivalent: "")
        mlxItem.isEnabled = false
        menu.addItem(mlxItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Open Cockpit", action: #selector(openCockpit), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Cockpit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Refresh periodically
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await refreshMenuBarStatus()
            }
        }
    }

    @objc @MainActor
    private func openCockpit() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc @MainActor
    private func refreshStatus() {
        Task { await refreshMenuBarStatus() }
    }

    @objc @MainActor
    private func quitApp() {
        NSApp.terminate(nil)
    }

    @MainActor
    private func refreshMenuBarStatus() async {
        guard let menu = statusItem?.menu else { return }

        // Check Ollama
        let ollamaReachable = await quickOllamaCheck()
        if let item = menu.items.first {
            item.title = ollamaReachable ? "◈ Ollama: ONLINE" : "◈ Ollama: OFFLINE"
        }

        // Update button color
        statusItem?.button?.title = ollamaReachable ? "◈" : "◇"
    }

    private func quickOllamaCheck() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode == 200
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let cockpitSelectTab = Notification.Name("cockpitSelectTab")
    static let cockpitToggle3D = Notification.Name("cockpitToggle3D")
    static let cockpitToggleJarvis = Notification.Name("cockpitToggleJarvis")
}
