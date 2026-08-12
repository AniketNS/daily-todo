import Foundation

/// Polls the clock and shows the morning/evening prompts on weekdays.
/// Snooze behaviour: if the user dismisses without resolving, the same
/// prompt is re-shown every `snoozeInterval` until it's resolved.
final class Scheduler {
    static let shared = Scheduler()

    private var timer: Timer?
    private let store = TaskStore.shared

    private var morningWindowOpen = false
    private var eveningWindowOpen = false
    private var hourlyWindowOpen = false

    /// Schedule/sound settings live in PreferencesStore (editable from the Preferences
    /// panel) so they can change without restarting the app.
    private var prefs: AppPreferences { PreferencesStore.shared.preferences }

    // Dev-only knob, not user-facing.
    private let pollInterval: TimeInterval

    private init() {
        let env = ProcessInfo.processInfo.environment
        pollInterval = TimeInterval(env["DAILYTODO_POLL_SECONDS"] ?? "") ?? 30
    }

    func start() {
        NotificationManager.shared.onOpenMorning = { [weak self] in
            guard let self, !self.morningWindowOpen else { return }
            self.morningWindowOpen = true
            self.openMorningPanel()
        }
        NotificationManager.shared.onOpenEvening = { [weak self] in
            guard let self, !self.eveningWindowOpen else { return }
            self.eveningWindowOpen = true
            self.openEveningPanel()
        }
        NotificationManager.shared.onOpenHourly = { [weak self] in
            guard let self, !self.hourlyWindowOpen else { return }
            self.hourlyWindowOpen = true
            self.openHourlyPanel()
        }

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        let now = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1 = Sun ... 7 = Sat
        guard weekday >= 2 && weekday <= 6 else { return } // Mon-Fri only

        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let minutesNow = hour * 60 + minute

        if minutesNow >= prefs.morningMinutes {
            store.ensureDefaultTasksForToday()
        }

        if minutesNow >= prefs.morningMinutes && !store.isMorningDone() && !morningWindowOpen {
            let snoozeInterval = TimeInterval(prefs.snoozeMinutes * 60)
            if shouldShow(lastShown: store.lastMorningPromptAt(), now: now, interval: snoozeInterval) {
                runMorningPrompt()
            }
        }

        if minutesNow >= prefs.eveningMinutes && !eveningWindowOpen {
            let pending = store.pendingTasksForToday()
            if !pending.isEmpty && now >= (store.nextEveningPromptAt() ?? .distantPast) {
                runEveningPrompt()
            }
        }

        if minutesNow >= prefs.morningMinutes && !hourlyWindowOpen && !morningWindowOpen && !eveningWindowOpen {
            let pending = store.pendingTasksForToday()
            let hourlyInterval = TimeInterval(prefs.hourlyIntervalMinutes * 60)
            if !pending.isEmpty && now.timeIntervalSince(store.lastHourlyPromptAt() ?? .distantPast) >= hourlyInterval {
                runHourlyReminder()
            }
        }
    }

    private func shouldShow(lastShown: Date?, now: Date, interval: TimeInterval) -> Bool {
        guard let lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= interval
    }

    // MARK: - Morning

    private func runMorningPrompt() {
        morningWindowOpen = true
        store.setLastMorningPromptAt(Date())

        if prefs.useNotificationBanners {
            NotificationManager.shared.post(
                kind: .morning,
                title: "Today's Tasks",
                body: "What are you working on today? Click to fill it in."
            )
            morningWindowOpen = false
            return
        }

        openMorningPanel()
    }

    private func openMorningPanel() {
        ReminderSound.play()
        let defaults = store.defaultTasksOrPendingForToday()
        let result = Prompts.showMorningPrompt(defaults: defaults)
        switch result {
        case .saved(let texts):
            store.saveTodayTasks(texts)
            store.markMorningDone()
        case .snoozed:
            break
        }
        morningWindowOpen = false
    }

    // MARK: - Evening

    private func runEveningPrompt() {
        eveningWindowOpen = true

        if prefs.useNotificationBanners {
            let pendingCount = store.pendingTasksForToday().count
            NotificationManager.shared.post(
                kind: .evening,
                title: "Still Pending",
                body: "\(pendingCount) task\(pendingCount == 1 ? "" : "s") not marked done yet. Click to review."
            )
            store.setNextEveningPromptAt(Date().addingTimeInterval(TimeInterval(prefs.eveningSnoozeMinutes * 60)))
            eveningWindowOpen = false
            return
        }

        openEveningPanel()
    }

    private func openEveningPanel() {
        ReminderSound.play()
        let pending = store.pendingTasksForToday()
        let chosenMinutes = Prompts.showEveningReview(tasks: pending) { id, action in
            switch action {
            case .completed: self.store.updateTaskStatus(id: id, status: .completed)
            case .tomorrow: self.store.moveTaskToTomorrow(id: id)
            case .notNeeded: self.store.updateTaskStatus(id: id, status: .dismissed)
            }
        }
        let snoozeMinutes = chosenMinutes ?? prefs.eveningSnoozeMinutes
        store.setNextEveningPromptAt(Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60)))
        eveningWindowOpen = false
    }

    // MARK: - Hourly

    private func runHourlyReminder() {
        hourlyWindowOpen = true
        store.setLastHourlyPromptAt(Date())

        if prefs.useNotificationBanners {
            let pendingCount = store.pendingTasksForToday().count
            NotificationManager.shared.post(
                kind: .hourly,
                title: "Today's Tasks",
                body: "\(pendingCount) task\(pendingCount == 1 ? "" : "s") pending. Click to check them off."
            )
            hourlyWindowOpen = false
            return
        }

        openHourlyPanel()
    }

    private func openHourlyPanel() {
        ReminderSound.play()
        Prompts.showTaskList(tasks: store.tasksForToday(), onChange: { id, status in
            self.store.updateTaskStatus(id: id, status: status)
        }, autoDismissAfter: 60)
        hourlyWindowOpen = false
    }
}
