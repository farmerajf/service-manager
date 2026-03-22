import SwiftUI

struct FunnelRowView: View {
    let funnel: FunnelConfiguration
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(funnel.pathPrefix)
                    .fontWeight(.medium)
                    .font(.system(.body, design: .monospaced))
                Text(verbatim: "→ localhost:\(funnel.localPort)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 2)
    }
}
