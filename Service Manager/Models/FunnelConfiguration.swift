import Foundation

struct FunnelConfiguration: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var pathPrefix: String
    var localPort: Int
}
