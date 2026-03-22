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
        }
    }
}

struct MenuBarMenuView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppViewModel.self) var viewModel

    private var runningCount: Int {
        viewModel.serviceManager.runners.values.filter {
            if case .running = $0.status { return true }
            if case .starting = $0.status { return true }
            return false
        }.count
    }

    var body: some View {
        Button("Configuration...") {
            openWindow(id: "configuration")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit Service Manager") {
            let count = runningCount
            if count > 0 {
                let alert = NSAlert()
                alert.messageText = "Quit Service Manager?"
                alert.informativeText = "Quitting will stop \(count) running service\(count == 1 ? "" : "s")."
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
        .keyboardShortcut("q", modifiers: .command)
    }
}
