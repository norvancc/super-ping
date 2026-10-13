import AVFoundation
import Foundation
import PingCore

/// Audio objects are owned exclusively by this queue, never by the UI/event-tap thread.
final class PingAudio {
    static let shared = PingAudio()
    private let queue = DispatchQueue(label: "dev.pingagent.audio", qos: .userInitiated)
    private var players: [String: [AVAudioPlayer]] = [:]
    private let lock = NSLock()
    private var hoverGate = HoverSoundGate()

    func prepare(bundle: Bundle, names: [String]) {
        queue.async { [self] in
            for name in names where players[name] == nil {
                guard let url = bundle.url(forResource: name, withExtension: "wav", subdirectory: "Resources/sounds") else { continue }
                // Separate voices avoid repeatedly stopping a currently playing hover sound.
                players[name] = (0..<3).compactMap { _ in
                    guard let player = try? AVAudioPlayer(contentsOf: url), player.prepareToPlay() else { return nil }
                    return player
                }
            }
        }
    }

    func hover() {
        let requested = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let accepted = hoverGate.accept(at: requested)
        lock.unlock()
        guard accepted else { return }
        queue.async { [self] in
            // Never play obsolete hover feedback after audio startup or device changes.
            guard ProcessInfo.processInfo.systemUptime - requested < 0.12 else { return }
            playAvailable("button")
        }
    }

    func play(_ name: String) {
        queue.async { [self] in playAvailable(name) }
    }

    private func playAvailable(_ name: String) {
        guard let voice = players[name]?.first(where: { !$0.isPlaying }) else { return }
        voice.currentTime = 0
        voice.play()
    }
}
