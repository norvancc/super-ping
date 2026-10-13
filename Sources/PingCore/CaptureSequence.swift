import Foundation

public enum CaptureSequence {
    public static let visibleDuration: UInt64 = 400_000_000
    public static let compositorDuration: UInt64 = 180_000_000

    @MainActor
    public static func prepare(
        show: () -> Void,
        freeze: () -> Void,
        hide: () -> Void,
        sleep: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async throws {
        show()
        do {
            try await sleep(visibleDuration)
            freeze()
            try await sleep(compositorDuration)
        } catch {
            hide()
            throw error
        }
        // The actual panel MUST remain visible until the caller has saved the capture.
    }
}
