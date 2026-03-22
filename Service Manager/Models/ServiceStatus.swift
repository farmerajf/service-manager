import Foundation

enum ServiceStatus: Equatable {
    case stopped
    case starting
    case running(pid: Int32)
    case crashed(exitCode: Int32, restartAt: Date?)
}
