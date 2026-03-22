import Foundation

struct ServiceConfiguration: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var workingDirectory: String
    var environmentVariables: [String: String]
    var autoRestart: Bool
    var autoStart: Bool
}
