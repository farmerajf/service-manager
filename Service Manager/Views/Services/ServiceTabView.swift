import SwiftUI

struct ServiceTabView: View {
    @Environment(AppViewModel.self) var viewModel
    @State private var showAddSheet = false

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationSplitView {
            ServiceListView(
                services: viewModel.configuration.services,
                runners: viewModel.serviceManager.runners,
                selection: $viewModel.selectedServiceID,
                onAdd: { showAddSheet = true }
            )
        } detail: {
            if let runner = viewModel.selectedRunner {
                ServiceDetailView(runner: runner)
            } else {
                ContentUnavailableView(
                    "Select a Service",
                    systemImage: "server.rack",
                    description: Text("Choose a service from the sidebar to view its console and controls.")
                )
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ServiceFormView(mode: .add) { config in
                viewModel.addService(config)
            }
        }
    }
}
