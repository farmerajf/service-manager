import SwiftUI

struct FunnelFormView: View {
    enum Mode {
        case add
        case edit(FunnelConfiguration)
    }

    let mode: Mode
    let onSave: (FunnelConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pathPrefix = "/"
    @State private var localPort = ""

    init(mode: Mode = .add, onSave: @escaping (FunnelConfiguration) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Funnel Mapping" : "Add Funnel Mapping")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                TextField("Path Prefix (e.g. /my-service)", text: $pathPrefix)

                TextField("Local Port", text: $localPort)
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
        .frame(width: 400, height: 300)
        .onAppear { loadFromMode() }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        pathPrefix.hasPrefix("/") && !pathPrefix.isEmpty && Int(localPort) != nil
    }

    private func loadFromMode() {
        if case .edit(let config) = mode {
            pathPrefix = config.pathPrefix
            localPort = "\(config.localPort)"
        }
    }

    private func save() {
        let id: UUID
        if case .edit(let config) = mode {
            id = config.id
        } else {
            id = UUID()
        }

        let config = FunnelConfiguration(
            id: id,
            pathPrefix: pathPrefix,
            localPort: Int(localPort) ?? 0
        )
        onSave(config)
        dismiss()
    }
}
