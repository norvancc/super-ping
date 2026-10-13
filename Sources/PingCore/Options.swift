import Foundation

public enum Localized {
    public static var preference = "auto"
    public static var chinese: Bool { preference == "zh-CN" || (preference == "auto" && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")) }
    public static func text(_ en: String, _ zh: String) -> String { chinese ? zh : en }
}

extension Ping {
    public static let defaultWheel: [Ping] = [.danger, .push, .onMyWay, .allIn, .assist, .needVision, .missing, .enemyVision]
    public var icon: String { switch self {
    case .danger: return "pingwheel_retreatrender"
    case .push: return "push"
    case .onMyWay: return "omw"
    case .allIn: return "all_in"
    case .assist: return "assist_me"
    case .needVision: return "need_vision"
    case .missing: return "enemy_missing"
    case .enemyVision: return "enemy_vision"
    case .generic: return "generic_ping"
    case .bait: return "pingwheel_baitrender"
    case .visionCleared: return "vision_cleared"
    } }
    public var artwork: [String] { switch self {
    case .push: return ["pingwheel_pushrender"]
    case .allIn: return ["pingwheel_allin_render_01", "pingwheel_allin_render_02"]
    case .enemyVision: return ["pingwheel_enemyvisionrender"]
    case .generic: return ["pingwheel_basicpingrender"]
    case .visionCleared: return ["pingwheel_visionclearedrender"]
    default: return [icon]
    } }
    public var soundName: String { switch self {
    case .danger: return "SRP_12"
    case .push: return "SRP_9"
    case .onMyWay: return "OnMyWay"
    case .allIn: return "SRP_4"
    case .assist: return "ComeHere"
    case .needVision: return "SRP_7"
    case .missing: return "MIA"
    case .enemyVision: return "AreaIsWarded"
    case .generic: return "Base"
    case .bait: return "SRP_11"
    case .visionCleared: return "SRP_6"
    } }
}

public struct Trigger: Codable, Equatable, Hashable {
    public var kind: String
    public var keyCode: UInt16
    public init(_ kind: String, keyCode: UInt16 = 0) { self.kind = kind; self.keyCode = keyCode }
    public var title: String { switch kind {
    case "option": return "⌥ Option"
    case "control": return "⌃ Control"
    case "shift": return "⇧ Shift"
    case "command": return "⌘ Command"
    case "mouse4": return Localized.text("Mouse 4", "鼠标 4")
    case "mouse5": return Localized.text("Mouse 5", "鼠标 5")
    case "off": return Localized.text("Off", "关闭")
    default: return KeyLabel.name(keyCode)
    } }
}
public struct CustomEmote: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var file: String
    public init(id: String, name: String, file: String) { self.id = id; self.name = name; self.file = file }
}
public struct Options: Codable, Equatable {
    public var trigger = Trigger("option")
    public var emoteTrigger = Trigger("control")
    public var dragThreshold: Double = 8
    public var clickPing = false
    public var clickPingID = Ping.generic
    public var wheel = Ping.defaultWheel
    public var hotkeyCode: UInt16 = 35
    public var hotkeyModifiers: UInt64 = (1 << 18) | (1 << 19)
    public var enabledOnStart = true
    public var pingSize: Double = 110
    public var pingDuration: Double = 3.2
    public var volume: Double = 70
    public var tickSound = true
    public var language = "auto"
    public var launchAtLogin = false
    public var emoteClick = false
    public var emoteWheel = EmoteDefinition.defaultWheel
    public var clickEmote = "facepalm"
    public var emoteSize: Double = 150
    public var emoteSound = true
    public var customEmotes: [CustomEmote] = []
    public var autoUpdateCheck = true
    public var updateNotifiedVersion: String? = nil
    public init() {}
    private enum CodingKeys: String, CodingKey { case trigger, emoteTrigger, dragThreshold, clickPing, clickPingID, wheel, hotkeyCode, hotkeyModifiers, enabledOnStart, pingSize, pingDuration, volume, tickSound, language, launchAtLogin, emoteClick, emoteWheel, clickEmote, emoteSize, emoteSound, customEmotes, autoUpdateCheck, updateNotifiedVersion }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trigger = (try? c.decode(type(of: trigger), forKey: .trigger)) ?? trigger
        emoteTrigger = (try? c.decode(type(of: emoteTrigger), forKey: .emoteTrigger)) ?? emoteTrigger
        dragThreshold = (try? c.decode(type(of: dragThreshold), forKey: .dragThreshold)) ?? dragThreshold
        clickPing = (try? c.decode(type(of: clickPing), forKey: .clickPing)) ?? clickPing
        clickPingID = (try? c.decode(type(of: clickPingID), forKey: .clickPingID)) ?? clickPingID
        wheel = (try? c.decode(type(of: wheel), forKey: .wheel)) ?? wheel
        hotkeyCode = (try? c.decode(type(of: hotkeyCode), forKey: .hotkeyCode)) ?? hotkeyCode
        hotkeyModifiers = (try? c.decode(type(of: hotkeyModifiers), forKey: .hotkeyModifiers)) ?? hotkeyModifiers
        enabledOnStart = (try? c.decode(type(of: enabledOnStart), forKey: .enabledOnStart)) ?? enabledOnStart
        pingSize = (try? c.decode(type(of: pingSize), forKey: .pingSize)) ?? pingSize
        pingDuration = (try? c.decode(type(of: pingDuration), forKey: .pingDuration)) ?? pingDuration
        volume = (try? c.decode(type(of: volume), forKey: .volume)) ?? volume
        tickSound = (try? c.decode(type(of: tickSound), forKey: .tickSound)) ?? tickSound
        language = (try? c.decode(type(of: language), forKey: .language)) ?? language
        launchAtLogin = (try? c.decode(type(of: launchAtLogin), forKey: .launchAtLogin)) ?? launchAtLogin
        emoteClick = (try? c.decode(type(of: emoteClick), forKey: .emoteClick)) ?? emoteClick
        emoteWheel = (try? c.decode(type(of: emoteWheel), forKey: .emoteWheel)) ?? emoteWheel
        clickEmote = (try? c.decode(type(of: clickEmote), forKey: .clickEmote)) ?? clickEmote
        emoteSize = (try? c.decode(type(of: emoteSize), forKey: .emoteSize)) ?? emoteSize
        emoteSound = (try? c.decode(type(of: emoteSound), forKey: .emoteSound)) ?? emoteSound
        customEmotes = (try? c.decode(type(of: customEmotes), forKey: .customEmotes)) ?? customEmotes
        autoUpdateCheck = (try? c.decode(type(of: autoUpdateCheck), forKey: .autoUpdateCheck)) ?? autoUpdateCheck
        updateNotifiedVersion = (try? c.decode(type(of: updateNotifiedVersion), forKey: .updateNotifiedVersion)) ?? updateNotifiedVersion
        normalize()
    }
    public var triggersClash: Bool {
        trigger == emoteTrigger || (emoteTrigger.kind == "custom" && emoteTrigger.keyCode == hotkeyCode)
    }
    public mutating func normalize() {
        let kinds = ["option", "control", "command", "shift", "mouse4", "mouse5", "custom"]
        if !kinds.contains(trigger.kind) || trigger.keyCode > 127 { trigger = Trigger("option") }
        if !(kinds + ["off"]).contains(emoteTrigger.kind) || emoteTrigger.keyCode > 127 { emoteTrigger = Trigger("control") }
        if trigger.kind != "custom" { trigger.keyCode = 0 }
        if emoteTrigger.kind != "custom" { emoteTrigger.keyCode = 0 }
        hotkeyModifiers &= (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
        if hotkeyCode > 127 { hotkeyCode = 35 }

        dragThreshold = min(40, max(2, dragThreshold.isFinite ? dragThreshold : 8))
        pingSize = min(220, max(60, pingSize.isFinite ? pingSize : 110))
        pingDuration = min(8, max(1, pingDuration.isFinite ? pingDuration : 3.2))
        volume = min(100, max(0, volume.isFinite ? volume : 70))
        emoteSize = min(300, max(80, emoteSize.isFinite ? emoteSize : 150))
        if wheel.count != 8 || Set(wheel).count != 8 { wheel = Ping.defaultWheel }
        if !["auto", "en", "zh-CN"].contains(language) { language = "auto" }
        if hotkeyModifiers & ((1 << 18) | (1 << 19) | (1 << 20)) == 0 { hotkeyModifiers = (1 << 18) | (1 << 19); hotkeyCode = 35 }
        if trigger == emoteTrigger || (emoteTrigger.kind == "custom" && emoteTrigger.keyCode == hotkeyCode) { emoteTrigger = Trigger("off") }
        customEmotes = Array(customEmotes.filter { UUID(uuidString: $0.id) != nil && !$0.file.contains("/") && !$0.file.contains("..") }.prefix(24))
        let known = Set(EmoteDefinition.catalog.map(\.id) + customEmotes.map(\.id))
        if emoteWheel.count != 8 || Set(emoteWheel).count != 8 { emoteWheel = EmoteDefinition.defaultWheel }
        for i in emoteWheel.indices where !known.contains(emoteWheel[i]) {
            emoteWheel[i] = EmoteDefinition.catalog.first { !emoteWheel.contains($0.id) }!.id
        }
        if !known.contains(clickEmote) { clickEmote = "facepalm" }
    }
    public static func placing<T: Equatable>(_ item: T, in wheel: [T], at index: Int) -> [T] {
        guard wheel.indices.contains(index) else { return wheel }
        var result = wheel
        if let old = wheel.firstIndex(of: item) { result.swapAt(old, index) } else { result[index] = item }
        return result
    }
}
