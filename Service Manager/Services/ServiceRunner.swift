import Foundation

@Observable
final class ServiceRunner {
    let configuration: ServiceConfiguration
    private(set) var status: ServiceStatus = .stopped
    let logBuffer: LogBuffer

    private let label: String
    private let serviceDirectory: URL
    private var stdoutSource: DispatchSourceFileSystemObject?
    private var stderrSource: DispatchSourceFileSystemObject?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var statusPollTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var restartCount: Int = 0
    private var stableTimer: Task<Void, Never>?
    private var isStopping = false
    private var trackedPID: pid_t?

    init(configuration: ServiceConfiguration, bufferSize: Int = 5000) {
        self.configuration = configuration
        self.logBuffer = LogBuffer(maxSize: bufferSize)
        self.label = "com.servicemanager.\(configuration.id.uuidString)"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.serviceDirectory = appSupport
            .appendingPathComponent("Service Manager/services/\(configuration.id.uuidString)")
    }

    func start() {
        switch status {
        case .stopped, .crashed(_, nil):
            break
        default:
            return
        }
        restartTask?.cancel()
        restartTask = nil
        performStart()
    }

    func stop() {
        isStopping = true
        defer { isStopping = false }

        restartTask?.cancel()
        restartTask = nil
        stableTimer?.cancel()
        stableTimer = nil
        restartCount = 0

        killTrackedProcess()
        bootoutJob()
        stopMonitoring()
        status = .stopped
    }

    func restart() {
        stop()
        performStart()
    }

    func clearLogs() {
        logBuffer.clear()
    }

    // MARK: - Paths

    private var plistURL: URL {
        serviceDirectory.appendingPathComponent("\(label).plist")
    }

    private var stdoutLogURL: URL {
        serviceDirectory.appendingPathComponent("stdout.log")
    }

    private var stderrLogURL: URL {
        serviceDirectory.appendingPathComponent("stderr.log")
    }

    private var pidFileURL: URL {
        serviceDirectory.appendingPathComponent("service.pid")
    }

    // MARK: - Lifecycle

    private func performStart() {
        status = .starting
        trackedPID = nil

        // Clean up any stale job from a previous run
        killTrackedProcess()
        bootoutJob()

        do {
            try FileManager.default.createDirectory(at: serviceDirectory, withIntermediateDirectories: true)
        } catch {
            status = .crashed(exitCode: -1, restartAt: nil)
            logBuffer.append(LogEntry(timestamp: Date(), stream: .stderr, text: "Failed to create directory: \(error.localizedDescription)"))
            return
        }

        // Create/truncate log files and pid file
        for url in [stdoutLogURL, stderrLogURL, pidFileURL] {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            if let handle = FileHandle(forWritingAtPath: url.path) {
                handle.truncateFile(atOffset: 0)
                handle.closeFile()
            }
        }

        // The wrapper script writes its PID then execs into the user's command.
        // This way the PID we track IS the command process.
        let pidFile = pidFileURL.path
        let wrappedCommand = "echo $$ > \(shellEscape(pidFile)); \(configuration.command)"

        // Build launchd plist
        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/bin/zsh", "-l", "-c", wrappedCommand],
            "WorkingDirectory": configuration.workingDirectory,
            "StandardOutPath": stdoutLogURL.path,
            "StandardErrorPath": stderrLogURL.path,
            "KeepAlive": false,
            "RunAtLoad": true,
        ]
        if !configuration.environmentVariables.isEmpty {
            plist["EnvironmentVariables"] = configuration.environmentVariables
        }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL)
        } catch {
            status = .crashed(exitCode: -1, restartAt: nil)
            logBuffer.append(LogEntry(timestamp: Date(), stream: .stderr, text: "Failed to write plist: \(error.localizedDescription)"))
            return
        }

        // Bootstrap the job via launchd
        let result = runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        if result.status != 0 {
            status = .crashed(exitCode: result.status, restartAt: nil)
            logBuffer.append(LogEntry(timestamp: Date(), stream: .stderr, text: "Failed to start: \(result.error)"))
            try? FileManager.default.removeItem(at: plistURL)
            return
        }

        startLogTailing()
        startStatusPolling()

        stableTimer?.cancel()
        stableTimer = Task {
            try? await Task.sleep(for: .seconds(60))
            if !Task.isCancelled {
                self.restartCount = 0
            }
        }
    }

    private func bootoutJob() {
        _ = runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    private func killTrackedProcess() {
        // Try PID from memory first, then from pidfile
        if let pid = trackedPID, pid > 0 {
            kill(-pid, SIGTERM) // Kill process group
            trackedPID = nil
        }
        // Also check pidfile for stale processes
        if let pidStr = try? String(contentsOf: pidFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let pid = pid_t(pidStr), pid > 0 {
            kill(-pid, SIGTERM)
        }
        try? FileManager.default.removeItem(at: pidFileURL)
    }

    private func shellEscape(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Log Tailing

    private func startLogTailing() {
        stdoutHandle = FileHandle(forReadingAtPath: stdoutLogURL.path)
        stderrHandle = FileHandle(forReadingAtPath: stderrLogURL.path)

        stdoutSource = makeLogSource(handle: stdoutHandle, stream: .stdout)
        stderrSource = makeLogSource(handle: stderrHandle, stream: .stderr)
    }

    private func makeLogSource(handle: FileHandle?, stream: LogEntry.LogStream) -> DispatchSourceFileSystemObject? {
        guard let handle else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: handle.fileDescriptor,
            eventMask: [.write, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in lines {
                self?.logBuffer.append(LogEntry(timestamp: Date(), stream: stream, text: line))
            }
        }
        source.resume()
        return source
    }

    // MARK: - Status Polling

    private func startStatusPolling() {
        statusPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    self.pollStatus()
                }
            }
        }
    }

    private func pollStatus() {
        // Try to read PID from pidfile if we don't have one yet
        if trackedPID == nil {
            if let pidStr = try? String(contentsOf: pidFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = pid_t(pidStr), pid > 0 {
                trackedPID = pid
            }
        }

        guard let pid = trackedPID else {
            // No PID yet — still starting
            return
        }

        // Check if process is alive
        let alive = kill(pid, 0) == 0

        if alive {
            if case .running = status { return }
            status = .running(pid: pid)
        } else {
            // Process exited — get exit status from launchctl
            let result = runLaunchctl(["list", label])
            let exitCode: Int32
            if result.status == 0, let exitStr = parseValue(from: result.output, key: "LastExitStatus") {
                exitCode = Int32(exitStr) ?? -1
            } else {
                exitCode = -1
            }

            switch status {
            case .running, .starting:
                handleProcessExit(exitCode: exitCode)
            default:
                break
            }
        }
    }

    private func parseValue(from output: String, key: String) -> String? {
        guard let range = output.range(of: "\"\(key)\" = "),
              let endRange = output[range.upperBound...].range(of: ";") else { return nil }
        return String(output[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Termination Handling

    private func handleProcessExit(exitCode: Int32) {
        guard !isStopping else { return }

        // Drain remaining logs before cleanup
        readRemainingLogs()
        bootoutJob()
        stopMonitoring()
        stableTimer?.cancel()
        trackedPID = nil

        if exitCode == 0 {
            status = .stopped
            return
        }

        if configuration.autoRestart {
            restartCount += 1
            let delay = min(pow(2.0, Double(restartCount)), 30.0)
            let restartAt = Date().addingTimeInterval(delay)
            status = .crashed(exitCode: exitCode, restartAt: restartAt)
            logBuffer.append(LogEntry(timestamp: Date(), stream: .stderr, text: "Process exited with code \(exitCode). Restarting in \(Int(delay))s..."))

            restartTask = Task {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self.performStart()
            }
        } else {
            status = .crashed(exitCode: exitCode, restartAt: nil)
            logBuffer.append(LogEntry(timestamp: Date(), stream: .stderr, text: "Process exited with code \(exitCode)."))
        }
    }

    private func readRemainingLogs() {
        for (handle, stream) in [(stdoutHandle, LogEntry.LogStream.stdout), (stderrHandle, LogEntry.LogStream.stderr)] {
            guard let handle else { continue }
            let data = handle.readDataToEndOfFile()
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { continue }
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in lines {
                logBuffer.append(LogEntry(timestamp: Date(), stream: stream, text: line))
            }
        }
    }

    // MARK: - Cleanup

    private func stopMonitoring() {
        statusPollTask?.cancel()
        statusPollTask = nil
        stdoutSource?.cancel()
        stderrSource?.cancel()
        stdoutHandle?.closeFile()
        stderrHandle?.closeFile()
        stdoutSource = nil
        stderrSource = nil
        stdoutHandle = nil
        stderrHandle = nil
    }

    // MARK: - Helpers

    private func runLaunchctl(_ arguments: [String]) -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return (
            process.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
