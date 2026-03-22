import Foundation

struct AppConfiguration: Codable {
    var services: [ServiceConfiguration] = []
    var funnels: [FunnelConfiguration] = []
    var logBufferSize: Int = 5000
}
