import Foundation

struct AppPreferences: Codable {
    var morningMinutes: Int = 10 * 60
    var eveningMinutes: Int = 16 * 60 + 30
    var snoozeMinutes: Int = 15
    var eveningSnoozeMinutes: Int = 30
    var hourlyIntervalMinutes: Int = 60
    var soundEnabled: Bool = true
    var useNotificationBanners: Bool = false

    /// Seeds defaults from the DAILYTODO_* environment variables used for local testing,
    /// so those still work the first time the app runs before any preferences are saved.
    static func seededFromEnvironment() -> AppPreferences {
        var prefs = AppPreferences()
        let env = ProcessInfo.processInfo.environment
        if let v = Int(env["DAILYTODO_MORNING_MINUTES"] ?? "") { prefs.morningMinutes = v }
        if let v = Int(env["DAILYTODO_EVENING_MINUTES"] ?? "") { prefs.eveningMinutes = v }
        if let v = env["DAILYTODO_SNOOZE_SECONDS"].flatMap(Int.init) { prefs.snoozeMinutes = v / 60 }
        if let v = env["DAILYTODO_EVENING_SNOOZE_SECONDS"].flatMap(Int.init) { prefs.eveningSnoozeMinutes = v / 60 }
        if let v = env["DAILYTODO_HOURLY_SECONDS"].flatMap(Int.init) { prefs.hourlyIntervalMinutes = v / 60 }
        return prefs
    }
}

/// Persists user-configurable schedule/sound settings, editable from the Preferences
/// panel instead of requiring environment variables and a rebuild.
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let fileURL: URL
    private(set) var preferences: AppPreferences

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DailyTodo", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("preferences.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .seededFromEnvironment()
        }
    }

    func update(_ mutate: (inout AppPreferences) -> Void) {
        mutate(&preferences)
        save()
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(preferences) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
