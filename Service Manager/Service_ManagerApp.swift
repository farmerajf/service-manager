import AppKit
import SwiftUI

@main
struct Service_ManagerApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Service Manager", systemImage: "server.rack") {
            MenuBarMenuView()
                .environment(viewModel)
        }

        Window("Service Manager", id: "configuration") {
            MainContentView()
                .environment(viewModel)
                .frame(minWidth: 700, minHeight: 500)
                .background(WindowDockVisibility())
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Service Manager") {
                    confirmQuit(runningCount: viewModel.serviceManager.runningCount)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

struct MenuBarMenuView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppViewModel.self) var viewModel

    var body: some View {
        Button("Configuration...") {
            openWindow(id: "configuration")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Service Manager") {
            confirmQuit(runningCount: viewModel.serviceManager.runningCount)
        }
    }
}

private func confirmQuit(runningCount: Int) {
    if runningCount > 0 {
        let alert = NSAlert()
        alert.messageText = "Quit Service Manager?"
        alert.informativeText = "Quitting will stop \(runningCount) running service\(runningCount == 1 ? "" : "s")."
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    } else {
        NSApplication.shared.terminate(nil)
    }
}

private struct WindowDockVisibility: NSViewRepresentable {
    func makeNSView(context: Context) -> DockObserverView {
        DockObserverView()
    }

    func updateNSView(_ nsView: DockObserverView, context: Context) {}
}

private class DockObserverView: NSView {
    private weak var observedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, observedWindow !== window else { return }

        if let observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: observedWindow)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
        }
        observedWindow = window
        NSApp.setActivationPolicy(.regular)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
