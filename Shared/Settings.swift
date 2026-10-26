import Foundation

enum Vibe: String, CaseIterable, Codable {
    case playful, flirty, witty, chill, sincere

    var label: String {
        switch self {
        case .playful: return "😜 Playful"
        case .flirty:  return "😏 Flirty"
        case .witty:   return "🧠 Witty"
        case .chill:   return "😎 Chill"
        case .sincere: return "🙂 Sincere"
        }
    }

    var guidance: String {
        switch self {
        case .playful: return "light teasing, fun, a little goofy, banter energy"
        case .flirty:  return "confident and flirty but classy, playful compliments, light tension, never crude"
        case .witty:   return "clever, dry humor, smart callbacks to what she said"
        case .chill:   return "relaxed, low-effort-looking but engaging, easygoing"
        case .sincere: return "warm, genuine, curious, asks a thoughtful follow-up question"
        }
    }
}

struct RizzSettings: Codable, Equatable {
    var serverURL: String = "http://192.168.1.100:11434"
    var model: String = "qwen2.5vl:7b"
    var vibe: Vibe = .playful
    var aboutMe: String = ""
}

enum SettingsStore {
    static let appGroup = "group.com.mariobarnaba.rizzkb"
    static let key = "rizz.settings.v1"
    static let configPrefix = "rizzkb-config:"

    /// Shared App Group store first (works when signing keeps the App Group),
    /// then this target's own store (the fallback used after a clipboard import).
    private static var stores: [UserDefaults] {
        [UserDefaults(suiteName: appGroup), UserDefaults.standard].compactMap { $0 }
    }

    static func load() -> RizzSettings {
        for store in stores {
            if let data = store.data(forKey: key),
               let s = try? JSONDecoder().decode(RizzSettings.self, from: data) {
                return s
            }
        }
        return RizzSettings()
    }

    static func save(_ settings: RizzSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        for store in stores { store.set(data, forKey: key) }
    }

    /// A string the companion app copies to the clipboard so the keyboard can
    /// import settings even if the App Group was stripped during sideloading.
    static func exportString(_ settings: RizzSettings) -> String {
        let data = (try? JSONEncoder().encode(settings)) ?? Data()
        return configPrefix + data.base64EncodedString()
    }

    static func importString(_ string: String) -> RizzSettings? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(configPrefix) else { return nil }
        let b64 = String(trimmed.dropFirst(configPrefix.count))
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(RizzSettings.self, from: data)
    }
}
