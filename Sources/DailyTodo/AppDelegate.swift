import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var loginItemMenuEntry: NSMenuItem!
    private var badgeTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imagePosition = .imageLeading
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Daily Todo")?
            .withSymbolConfiguration(config)
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()

        menu.addItem(makeItem("Today's Tasks", #selector(showTodayTasks)))
        menu.addItem(makeItem("Add Task…", #selector(addTask)))
        menu.addItem(makeItem("Edit Default Tasks…", #selector(editDefaults)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Preferences…", #selector(showPreferences), keyEquivalent: ","))

        loginItemMenuEntry = makeItem("Launch at Login", #selector(toggleLaunchAtLogin))
        loginItemMenuEntry.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItemMenuEntry)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Quit", #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu

        if PreferencesStore.shared.preferences.useNotificationBanners {
            NotificationManager.shared.requestAuthorization()
        }

        Scheduler.shared.start()
        startBadgeRefresh()
    }

    private func startBadgeRefresh() {
        refreshBadge()
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshBadge()
        }
    }

    private func refreshBadge() {
        let count = TaskStore.shared.pendingTasksForToday().count
        statusItem.button?.title = count > 0 ? " \(count)" : ""
    }

    private func makeItem(_ title: String, _ action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func showTodayTasks() {
        Prompts.showTaskList(tasks: TaskStore.shared.tasksForToday()) { id, status in
            TaskStore.shared.updateTaskStatus(id: id, status: status)
        }
        refreshBadge()
    }

    @objc private func addTask() {
        for text in Prompts.promptForNewTasks() {
            TaskStore.shared.addTask(text: text)
        }
        refreshBadge()
    }

    @objc private func editDefaults() {
        let current = TaskStore.shared.defaultTasks()
        let updated = Prompts.promptForDefaults(current: current)
        TaskStore.shared.setDefaultTasks(updated)
    }

    @objc private func showPreferences() {
        PreferencesPanelController().run()
    }

    @objc private func toggleLaunchAtLogin() {
        let succeeded = LaunchAtLogin.toggle()
        if !succeeded {
            let alert = NSAlert()
            alert.messageText = "Couldn't update Login Items"
            alert.informativeText = "You can enable this manually in System Settings > General > Login Items & Extensions."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        loginItemMenuEntry.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
