import Foundation

struct TailscaleFunnelStatus: Codable {
    let TCP: [String: TCPConfig]?
    let Web: [String: WebConfig]?
    let AllowFunnel: [String: Bool]?

    struct TCPConfig: Codable {
        let HTTPS: Bool?
    }

    struct WebConfig: Codable {
        let Handlers: [String: Handler]?
    }

    struct Handler: Codable {
        let Proxy: String?
    }
}

@Observable
final class TailscaleManager {
    private(set) var currentStatus: TailscaleFunnelStatus?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let tailscalePath = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

    func refreshStatus() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let output = try await runTailscale(["funnel", "status", "--json"])
            if let data = output.data(using: .utf8) {
                currentStatus = try JSONDecoder().decode(TailscaleFunnelStatus.self, from: data)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func parseFunnelsFromStatus() -> [FunnelConfiguration] {
        guard let status = currentStatus, let webConfigs = status.Web else { return [] }
        var funnels: [FunnelConfiguration] = []
        for (_, webConfig) in webConfigs {
            guard let handlers = webConfig.Handlers else { continue }
            for (path, handler) in handlers {
                guard let proxy = handler.Proxy,
                      let url = URL(string: proxy),
                      let port = url.port else { continue }
                funnels.append(FunnelConfiguration(pathPrefix: path, localPort: port))
            }
        }
        return funnels.sorted { $0.pathPrefix < $1.pathPrefix }
    }

    func addFunnel(path: String, port: Int) async throws {
        _ = try await runTailscale(["funnel", "--bg", "--set-path", path, "\(port)", "--yes"])
        await refreshStatus()
    }

    func removeFunnel(path: String) async throws {
        _ = try await runTailscale(["funnel", "--set-path", path, "off", "--yes"])
        await refreshStatus()
    }

    private func runTailscale(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tailscalePath)
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw TailscaleError.commandFailed(errorString)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum TailscaleError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Tailscale error: \(message)"
        }
    }
}
