import Foundation

@Observable
final class ServiceManager {
    private(set) var runners: [UUID: ServiceRunner] = [:]

    func runner(for config: ServiceConfiguration, bufferSize: Int = 5000) -> ServiceRunner {
        if let existing = runners[config.id] {
            return existing
        }
        let runner = ServiceRunner(configuration: config, bufferSize: bufferSize)
        runners[config.id] = runner
        return runner
    }

    func removeRunner(for id: UUID) {
        if let runner = runners[id] {
            runner.stop()
        }
        runners.removeValue(forKey: id)
    }

    func startAll(configs: [ServiceConfiguration]) {
        for config in configs where config.autoStart {
            let r = runner(for: config)
            r.start()
        }
    }

    func stopAll() {
        for runner in runners.values {
            runner.stop()
        }
    }
}
