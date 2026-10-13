import AppKit
import PingCore

/// Runs on a worker task. Never activates another app or changes browser tabs.
enum ContextCapture {
    private static let chromium = Set(["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary", "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi", "org.chromium.Chromium"])
    static func capture(point: CGPoint, primaryHeight: CGFloat) -> PingContext {
        let cgPoint = CGPoint(x: point.x, y: primaryHeight - point.y)
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let window = windows.first(where: { item in
                  guard (item[kCGWindowLayer as String] as? Int) == 0,
                        let bounds = item[kCGWindowBounds as String] as? [String: Any],
                        let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.contains(cgPoint) else { return false }
                  return (item[kCGWindowAlpha as String] as? Double ?? 1) > 0
              }), let pid = window[kCGWindowOwnerPID as String] as? Int32 else {
            return PingContext(application: "Unknown", note: "No application window found at the ping position.")
        }
        let app = NSRunningApplication(processIdentifier: pid)
        let bundle = app?.bundleIdentifier
        var context = PingContext(application: app?.localizedName ?? (window[kCGWindowOwnerName as String] as? String ?? "Unknown"), bundleIdentifier: bundle, windowTitle: window[kCGWindowName as String] as? String)
        guard let bundle, bundle == "com.apple.Safari" || chromium.contains(bundle) else { return context }
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any], let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return context }
        // Match the exact window under the pointer, not the browser's front window (which may be on another screen).
        let tab = bundle == "com.apple.Safari" ? "current tab of w" : "active tab of w"
        let title = bundle == "com.apple.Safari" ? "name" : "title"
        let x = Int(rect.minX.rounded()), y = Int(rect.minY.rounded()), right = Int(rect.maxX.rounded()), bottom = Int(rect.maxY.rounded())
        let script = """
        with timeout of 3 seconds
            tell application id "\(bundle)"
                repeat with w in windows
                    set b to bounds of w
                    if (item 1 of b is \(x)) and (item 2 of b is \(y)) and (item 3 of b is \(right)) and (item 4 of b is \(bottom)) then
                        set t to \(tab)
                        return (URL of t as text) & linefeed & (\(title) of t as text)
                    end if
                end repeat
            end tell
        end timeout
        """
        switch run(script) {
        case .success(let output):
            let parts = output.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            context.pageURL = PingContext.webURL(parts.first.map(String.init))
            if parts.count > 1 { context.pageTitle = String(parts[1]).trimmingCharacters(in: .newlines) }
            if context.pageURL == nil { context.note = "Browser window did not match, or this tab has no HTTP(S) URL." }
        case .failure(let error):
            context.note = error.localizedDescription
        }
        return context
    }
    private static func run(_ script: String) -> Result<String, Error> {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe(); process.standardOutput = output
        let errors = Pipe(); process.standardError = errors
        // Outputs are just a URL/title or a short AppleScript error. Read concurrently to avoid pipe backpressure.
        let reader = DispatchGroup()
        final class Bytes: @unchecked Sendable { var output = Data(); var error = Data() }
        let bytes = Bytes()
        do {
            try process.run()
            reader.enter(); DispatchQueue.global().async { bytes.output = output.fileHandleForReading.readDataToEndOfFile(); reader.leave() }
            reader.enter(); DispatchQueue.global().async { bytes.error = errors.fileHandleForReading.readDataToEndOfFile(); reader.leave() }
            let deadline = Date().addingTimeInterval(4)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            if process.isRunning {
                process.terminate()
                return .failure(ActionFailure(message: "Browser context timed out; screenshot is still available."))
            }
            reader.wait()
            guard process.terminationStatus == 0 else {
                return .failure(ActionFailure(message: "Browser URL unavailable (automation permission may be required)."))
            }
            return .success(String(decoding: bytes.output, as: UTF8.self))
        } catch { return .failure(error) }
    }
}
