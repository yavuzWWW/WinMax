import Foundation

final class WinMaxLogger {
    static let shared = WinMaxLogger()

    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }

    private let queue = DispatchQueue(label: "cloud.vasthosting.winmax.logger")
    let logDirectory: URL
    let logFile: URL

    private init() {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        logDirectory = base.appendingPathComponent("Logs/WinMax", isDirectory: true)
        logFile = logDirectory.appendingPathComponent("winmax.log")
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        rotateIfNeeded()
        info("WinMax logger initialized")
    }

    func debug(_ message: String) { write(.debug, message) }
    func info(_ message: String) { write(.info, message) }
    func warning(_ message: String) { write(.warning, message) }
    func error(_ message: String) { write(.error, message) }

    private func write(_ level: Level, _ message: String) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) [\(level.rawValue)] \(message)\n"

        queue.async { [logFile] in
            guard let data = line.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: logFile.path) {
                FileManager.default.createFile(atPath: logFile.path, contents: nil)
            }
            do {
                let handle = try FileHandle(forWritingTo: logFile)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                NSLog("WinMax logging failed: %@", error.localizedDescription)
            }
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? NSNumber,
              size.intValue > 1_500_000 else { return }

        let old = logDirectory.appendingPathComponent("winmax.previous.log")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: logFile, to: old)
    }
}
