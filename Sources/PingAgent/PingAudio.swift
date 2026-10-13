import AVFoundation
import Foundation
import PingCore

/// Audio objects are owned exclusively by this queue, never by the UI/event-tap thread.
final class PingAudio {
    static let shared = PingAudio()
    private let queue = DispatchQueue(label: "dev.pingagent.audio", qos: .userInitiated)
    private var players: [String: [AVAudioPlayer]] = [:]
    private let lock = NSLock()
    private var volume: Float = 0.7
    func setVolume(_ value: Double) { queue.async { self.volume = Float(max(0, min(100, value)) / 100) } }
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

    func prepareFiles(_ urls: [URL]) {
        queue.async { [self] in
            for url in urls where players[url.path] == nil {
                players[url.path] = (0..<3).compactMap { _ in
                    guard let player = try? AVAudioPlayer(contentsOf: url), player.prepareToPlay() else { return nil }
                    return player
                }
            }
        }
    }
    func playFile(_ url: URL) {
        queue.async { [self] in
            let key = url.path
            if players[key] == nil, let player = try? AVAudioPlayer(contentsOf: url) { player.prepareToPlay(); players[key] = [player] }
            playAvailable(key)
        }
    }
    private func playAvailable(_ name: String) {
        guard volume > 0, players.values.flatMap({ $0 }).filter({ $0.isPlaying }).count < 8 else { return }
        if players[name]?.allSatisfy({ $0.isPlaying }) == true, let url = players[name]?.first?.url,
           let extra = try? AVAudioPlayer(contentsOf: url), extra.prepareToPlay() { players[name]?.append(extra) }
        guard let voice = players[name]?.first(where: { !$0.isPlaying }) else { return }
        voice.volume = volume
        voice.currentTime = 0
        voice.play()
    }
}
