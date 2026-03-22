import Foundation

@Observable
final class LogBuffer {
    private var buffer: [LogEntry] = []
    private let maxSize: Int

    var entries: [LogEntry] {
        buffer
    }

    var count: Int {
        buffer.count
    }

    init(maxSize: Int = 5000) {
        self.maxSize = maxSize
    }

    func append(_ entry: LogEntry) {
        buffer.append(entry)
        if buffer.count > maxSize {
            buffer.removeFirst(buffer.count - maxSize)
        }
    }

    func clear() {
        buffer.removeAll()
    }
}
