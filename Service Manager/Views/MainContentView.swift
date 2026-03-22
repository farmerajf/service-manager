import SwiftUI

struct MainContentView: View {
    @Environment(AppViewModel.self) var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        TabView(selection: $viewModel.selectedTab) {
            Tab("Services", systemImage: "gear", value: AppViewModel.AppTab.services) {
                ServiceTabView()
            }
            Tab("Funnel", systemImage: "network", value: AppViewModel.AppTab.funnels) {
                FunnelTabView()
            }
        }
    }
}
