import SwiftUI

struct ServiceListView: View {
    let services: [ServiceConfiguration]
    let runners: [UUID: ServiceRunner]
    @Binding var selection: UUID?
    let onAdd: () -> Void

    var body: some View {
        List(services, selection: $selection) { service in
            ServiceRowView(service: service, runner: runners[service.id])
                .tag(service.id)
        }
        .toolbar {
            ToolbarItem {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
