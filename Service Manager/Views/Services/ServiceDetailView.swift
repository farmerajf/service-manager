import SwiftUI

struct ServiceDetailView: View {
    let runner: ServiceRunner
    @Environment(AppViewModel.self) var viewModel
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(runner.configuration.name)
                        .font(.headline)
                    statusText
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { runner.start() }) {
                        Image(systemName: "play.fill")
                    }
                    .disabled(!canStart)

                    Button(action: { runner.stop() }) {
                        Image(systemName: "stop.fill")
                    }
                    .disabled(!canStop)

                    Button(action: { runner.restart() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!canStop)

                    Divider()
                        .frame(height: 16)

                    Button(action: { runner.clearLogs() }) {
                        Image(systemName: "trash")
                    }

                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "pencil")
                    }

                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "xmark.circle")
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(12)

            Divider()

            // Console output
            ConsoleView(logBuffer: runner.logBuffer)
        }
        .sheet(isPresented: $showEditSheet) {
            ServiceFormView(mode: .edit(runner.configuration)) { config in
                viewModel.updateService(config)
            }
        }
        .confirmationDialog("Delete Service", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteService(id: runner.configuration.id)
            }
        } message: {
            Text("Are you sure you want to delete \"\(runner.configuration.name)\"? This will stop the service if running.")
        }
    }

    private var canStart: Bool {
        switch runner.status {
        case .stopped:
            return true
        case .crashed(_, let restartAt):
            return restartAt == nil
        default:
            return false
        }
    }

    private var canStop: Bool {
        switch runner.status {
        case .running, .starting:
            return true
        case .crashed(_, let restartAt):
            return restartAt != nil
        default:
            return false
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch runner.status {
        case .stopped:
            Text("Stopped")
        case .starting:
            Text("Starting...")
        case .running(let pid):
            Text(verbatim: "Running (PID \(pid))")
        case .crashed(let code, let restartAt):
            if let restartAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(restartAt.timeIntervalSince(context.date)))
                    Text(verbatim: "Crashed (exit \(code)) — restarting in \(remaining)s")
                }
            } else {
                Text(verbatim: "Crashed (exit \(code))")
            }
        }
    }
}
