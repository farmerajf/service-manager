import SwiftUI

struct ServiceFormView: View {
    enum Mode {
        case add
        case edit(ServiceConfiguration)
    }

    let mode: Mode
    let onSave: (ServiceConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = ""
    @State private var envVars: [(key: String, value: String)] = []
    @State private var autoRestart = true
    @State private var autoStart = false

    init(mode: Mode, onSave: @escaping (ServiceConfiguration) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Service" : "Add Service")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("General") {
                    TextField("Service Name", text: $name)
                }

                Section("Execution") {
                    TextField("Command (e.g. npm run start)", text: $command)
                    HStack {
                        TextField("Working Directory", text: $workingDirectory)
                        Button("Browse...") { browseDirectory() }
                    }
                }

                Section("Environment Variables") {
                    ForEach(envVars.indices, id: \.self) { index in
                        HStack {
                            TextField("Key", text: Binding(
                                get: { envVars[index].key },
                                set: { envVars[index].key = $0 }
                            ))
                            TextField("Value", text: Binding(
                                get: { envVars[index].value },
                                set: { envVars[index].value = $0 }
                            ))
                            Button(action: { envVars.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button(action: { envVars.append((key: "", value: "")) }) {
                        Label("Add Variable", systemImage: "plus")
                    }
                }

                Section("Options") {
                    Toggle("Auto-restart on crash", isOn: $autoRestart)
                    Toggle("Start on app launch", isOn: $autoStart)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear { loadFromMode() }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.isEmpty && !command.isEmpty && !workingDirectory.isEmpty
    }

    private func loadFromMode() {
        if case .edit(let config) = mode {
            name = config.name
            command = config.command
            workingDirectory = config.workingDirectory
            envVars = config.environmentVariables.map { (key: $0.key, value: $0.value) }
            autoRestart = config.autoRestart
            autoStart = config.autoStart
        }
    }

    private func save() {
        let id: UUID
        if case .edit(let config) = mode {
            id = config.id
        } else {
            id = UUID()
        }

        let config = ServiceConfiguration(
            id: id,
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            environmentVariables: Dictionary(uniqueKeysWithValues: envVars.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }),
            autoRestart: autoRestart,
            autoStart: autoStart
        )
        onSave(config)
        dismiss()
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}
