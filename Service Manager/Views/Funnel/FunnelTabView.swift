import SwiftUI

struct FunnelTabView: View {
    @Environment(AppViewModel.self) var viewModel
    @State private var showAddSheet = false
    @State private var editingFunnel: FunnelConfiguration?
    @State private var errorMessage: String?
    @State private var deletingFunnelID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tailscale Funnel Mappings")
                    .font(.headline)
                Spacer()
                if viewModel.tailscaleManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button(action: {
                    Task {
                        await viewModel.tailscaleManager.refreshStatus()
                        viewModel.syncFunnelsFromTailscale()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .padding()

            Divider()

            if viewModel.configuration.funnels.isEmpty {
                ContentUnavailableView(
                    "No Funnel Mappings",
                    systemImage: "network",
                    description: Text("Add a funnel mapping to expose a local service via Tailscale.")
                )
            } else {
                List {
                    ForEach(viewModel.configuration.funnels) { funnel in
                        FunnelRowView(
                            funnel: funnel,
                            onDelete: { deletingFunnelID = funnel.id },
                            onEdit: { editingFunnel = funnel }
                        )
                    }
                }
            }

            if let error = viewModel.tailscaleManager.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(.yellow.opacity(0.1))
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") { self.errorMessage = nil }
                        .controlSize(.small)
                }
                .padding(8)
                .background(.red.opacity(0.1))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            FunnelFormView { config in
                Task {
                    do {
                        try await viewModel.addFunnel(config)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .sheet(item: $editingFunnel) { funnel in
            FunnelFormView(mode: .edit(funnel)) { newConfig in
                Task {
                    do {
                        try await viewModel.updateFunnel(funnel, newConfig)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .confirmationDialog("Delete Funnel Mapping", isPresented: .init(
            get: { deletingFunnelID != nil },
            set: { if !$0 { deletingFunnelID = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let id = deletingFunnelID {
                    Task {
                        do {
                            try await viewModel.deleteFunnel(id: id)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure? This will remove the Tailscale funnel mapping.")
        }
    }
}
