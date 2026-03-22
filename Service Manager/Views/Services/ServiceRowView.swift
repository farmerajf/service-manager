import SwiftUI

struct ServiceRowView: View {
    let service: ServiceConfiguration
    let runner: ServiceRunner?

    var body: some View {
        HStack(spacing: 8) {
            StatusBadgeView(status: runner?.status ?? .stopped)
            Text(service.name)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
