import Foundation

/// Lightweight file logger for diagnosing capture/permission issues.
/// Writes to /tmp/parrot-debug.log so it can be inspected without Console.app.
enum DebugLog {
    private static let url = URL(fileURLWithPath: "/tmp/parrot-debug.log")
    private static let queue = DispatchQueue(label: "parrot.debuglog")

    static func log(_ message: String) {
        let line = "[\(ts())] \(message)\n"
        queue.async {
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: url, options: .atomic)
                }
            }
        }
    }

    private static func ts() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
