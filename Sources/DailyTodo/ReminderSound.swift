import AppKit

/// Plays a short system alert sound when an automatic reminder pops up on screen,
/// so it's noticeable even if the app isn't in focus.
enum ReminderSound {
    static func play() {
        guard PreferencesStore.shared.preferences.soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }
}
