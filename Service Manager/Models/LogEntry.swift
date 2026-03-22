import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let stream: LogStream
    let text: String

    enum LogStream {
        case stdout
        case stderr
    }
}
