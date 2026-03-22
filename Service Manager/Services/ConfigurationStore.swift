import Foundation

final class ConfigurationStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Service Manager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("config.json")
    }

    func load() -> AppConfiguration {
        guard let data = try? Data(contentsOf: fileURL) else {
            return AppConfiguration()
        }
        return (try? JSONDecoder().decode(AppConfiguration.self, from: data)) ?? AppConfiguration()
    }

    func save(_ config: AppConfiguration) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
