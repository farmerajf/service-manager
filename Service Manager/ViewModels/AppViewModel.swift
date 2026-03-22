import Foundation
import AppKit

@Observable
final class AppViewModel {
    var configuration: AppConfiguration
    var selectedServiceID: UUID?
    var selectedTab: AppTab = .services

    let serviceManager = ServiceManager()
    let tailscaleManager = TailscaleManager()
    private let configStore = ConfigurationStore()
    private var terminationObserver: Any?

    enum AppTab: String, CaseIterable, Identifiable {
        case services = "Services"
        case funnels = "Tailscale Funnel"

        var id: String { rawValue }
    }

    init() {
        self.configuration = configStore.load()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onAppLaunch()
        }
    }

    var selectedRunner: ServiceRunner? {
        guard let id = selectedServiceID else { return nil }
        return serviceManager.runners[id]
    }

    // MARK: - Lifecycle

    func onAppLaunch() {
        for config in configuration.services {
            _ = serviceManager.runner(for: config, bufferSize: configuration.logBufferSize)
        }
        serviceManager.startAll(configs: configuration.services)

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.serviceManager.stopAll()
        }

        Task {
            await tailscaleManager.refreshStatus()
            syncFunnelsFromTailscale()
        }
    }

    // MARK: - Service CRUD

    func addService(_ config: ServiceConfiguration) {
        configuration.services.append(config)
        _ = serviceManager.runner(for: config, bufferSize: configuration.logBufferSize)
        saveConfiguration()
    }

    func updateService(_ config: ServiceConfiguration) {
        if let index = configuration.services.firstIndex(where: { $0.id == config.id }) {
            let wasRunning: Bool
            if let runner = serviceManager.runners[config.id] {
                if case .running = runner.status {
                    wasRunning = true
                    runner.stop()
                } else {
                    wasRunning = false
                }
            } else {
                wasRunning = false
            }

            configuration.services[index] = config
            serviceManager.removeRunner(for: config.id)
            let runner = serviceManager.runner(for: config, bufferSize: configuration.logBufferSize)

            if wasRunning {
                runner.start()
            }

            saveConfiguration()
        }
    }

    func deleteService(id: UUID) {
        serviceManager.removeRunner(for: id)
        configuration.services.removeAll { $0.id == id }
        if selectedServiceID == id {
            selectedServiceID = nil
        }
        saveConfiguration()
    }

    // MARK: - Funnel CRUD

    func addFunnel(_ config: FunnelConfiguration) async throws {
        try await tailscaleManager.addFunnel(path: config.pathPrefix, port: config.localPort)
        configuration.funnels.append(config)
        saveConfiguration()
    }

    func updateFunnel(_ oldConfig: FunnelConfiguration, _ newConfig: FunnelConfiguration) async throws {
        try await tailscaleManager.removeFunnel(path: oldConfig.pathPrefix)
        try await tailscaleManager.addFunnel(path: newConfig.pathPrefix, port: newConfig.localPort)
        if let index = configuration.funnels.firstIndex(where: { $0.id == oldConfig.id }) {
            configuration.funnels[index] = newConfig
        }
        saveConfiguration()
    }

    func deleteFunnel(id: UUID) async throws {
        guard let funnel = configuration.funnels.first(where: { $0.id == id }) else { return }
        try await tailscaleManager.removeFunnel(path: funnel.pathPrefix)
        configuration.funnels.removeAll { $0.id == id }
        saveConfiguration()
    }

    // MARK: - Tailscale Sync

    func syncFunnelsFromTailscale() {
        let liveFunnels = tailscaleManager.parseFunnelsFromStatus()
        // Build a lookup of existing funnels by (path, port) to preserve IDs
        let existingByKey = Dictionary(
            uniqueKeysWithValues: configuration.funnels.map { ($0.pathPrefix + ":\($0.localPort)", $0) }
        )
        configuration.funnels = liveFunnels.map { funnel in
            let key = funnel.pathPrefix + ":\(funnel.localPort)"
            if let existing = existingByKey[key] {
                return existing
            }
            return funnel
        }
        saveConfiguration()
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        configStore.save(configuration)
    }
}
