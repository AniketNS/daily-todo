import AppKit

/// Settings panel for the schedule/sound preferences that used to require environment
/// variables and a rebuild. Every control saves immediately on change.
final class PreferencesPanelController: NSObject {
    private var panel: FancyPanel!

    func run() {
        let panel = FancyPanel(width: 380, height: 480)
        self.panel = panel
        panel.onCancel = { [weak self] in self?.finish() }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        panel.cardView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: panel.cardView.topAnchor, constant: 22),
            container.leadingAnchor.constraint(equalTo: panel.cardView.leadingAnchor, constant: 22),
            container.trailingAnchor.constraint(equalTo: panel.cardView.trailingAnchor, constant: -22),
            container.bottomAnchor.constraint(equalTo: panel.cardView.bottomAnchor, constant: -20),
        ])

        let (badge, _) = FancyStyle.iconBadge(systemSymbol: "gearshape.fill")
        let titleLabel = FancyStyle.titleLabel("Preferences")
        let subtitleLabel = FancyStyle.subtitleLabel("Changes are saved immediately.")
        let closeButton = FancyStyle.closeButton(target: self, action: #selector(finish))

        container.addSubview(badge)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor, constant: -7),
            titleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),
        ])

        let prefs = PreferencesStore.shared.preferences

        let morningPicker = timePicker(minutes: prefs.morningMinutes, action: #selector(morningTimeChanged(_:)))
        let eveningPicker = timePicker(minutes: prefs.eveningMinutes, action: #selector(eveningTimeChanged(_:)))
        let snoozePopup = popup(
            options: [5, 10, 15, 20, 30], current: prefs.snoozeMinutes, action: #selector(snoozeChanged(_:))
        )
        let eveningSnoozePopup = popup(
            options: [10, 15, 20, 30, 45, 60], current: prefs.eveningSnoozeMinutes,
            action: #selector(eveningSnoozeChanged(_:))
        )
        let hourlyPopup = popup(
            options: [30, 45, 60, 90, 120], current: prefs.hourlyIntervalMinutes, action: #selector(hourlyChanged(_:))
        )
        let soundSwitch = toggle(isOn: prefs.soundEnabled, action: #selector(soundToggled(_:)))
        let bannerSwitch = toggle(isOn: prefs.useNotificationBanners, action: #selector(bannerToggled(_:)))

        let rows = [
            formRow(label: "Morning prompt time", control: morningPicker),
            formRow(label: "Evening review time", control: eveningPicker),
            formRow(label: "Morning snooze", control: snoozePopup),
            formRow(label: "Evening default snooze", control: eveningSnoozePopup),
            formRow(label: "Hourly check-in interval", control: hourlyPopup),
            formRow(label: "Play sound on reminders", control: soundSwitch),
            formRow(label: "Use notification banners", control: bannerSwitch),
        ]

        let formStack = NSStackView(views: rows)
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        rows.forEach { $0.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true }

        let doneButton = FancyStyle.primaryButton(title: "Done", target: self, action: #selector(finish))

        container.addSubview(formStack)
        container.addSubview(doneButton)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            formStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            doneButton.topAnchor.constraint(greaterThanOrEqualTo: formStack.bottomAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
    }

    // MARK: - Control builders

    private func formRow(label: String, control: NSView) -> NSView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)
        labelField.textColor = .labelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelField)
        row.addSubview(control)
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.leadingAnchor.constraint(greaterThanOrEqualTo: labelField.trailingAnchor, constant: 8),

            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
        ])
        return row
    }

    private func timePicker(minutes: Int, action: Selector) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerElements = [.hourMinute]
        picker.datePickerStyle = .textFieldAndStepper
        picker.dateValue = Self.date(fromMinutes: minutes)
        picker.target = self
        picker.action = action
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }

    private func popup(options: [Int], current: Int, action: Selector) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        var allOptions = options
        if !allOptions.contains(current) {
            allOptions.append(current)
            allOptions.sort()
        }
        for value in allOptions {
            let item = NSMenuItem(title: "\(value) min", action: nil, keyEquivalent: "")
            item.tag = value
            popup.menu?.addItem(item)
        }
        popup.selectItem(withTag: current)
        popup.target = self
        popup.action = action
        popup.translatesAutoresizingMaskIntoConstraints = false
        return popup
    }

    private func toggle(isOn: Bool, action: Selector) -> NSSwitch {
        let toggle = NSSwitch()
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = action
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }

    // MARK: - Actions

    @objc private func morningTimeChanged(_ sender: NSDatePicker) {
        let minutes = Self.minutes(fromDate: sender.dateValue)
        PreferencesStore.shared.update { $0.morningMinutes = minutes }
    }

    @objc private func eveningTimeChanged(_ sender: NSDatePicker) {
        let minutes = Self.minutes(fromDate: sender.dateValue)
        PreferencesStore.shared.update { $0.eveningMinutes = minutes }
    }

    @objc private func snoozeChanged(_ sender: NSPopUpButton) {
        let value = sender.selectedTag()
        PreferencesStore.shared.update { $0.snoozeMinutes = value }
    }

    @objc private func eveningSnoozeChanged(_ sender: NSPopUpButton) {
        let value = sender.selectedTag()
        PreferencesStore.shared.update { $0.eveningSnoozeMinutes = value }
    }

    @objc private func hourlyChanged(_ sender: NSPopUpButton) {
        let value = sender.selectedTag()
        PreferencesStore.shared.update { $0.hourlyIntervalMinutes = value }
    }

    @objc private func soundToggled(_ sender: NSSwitch) {
        PreferencesStore.shared.update { $0.soundEnabled = sender.state == .on }
    }

    @objc private func bannerToggled(_ sender: NSSwitch) {
        PreferencesStore.shared.update { $0.useNotificationBanners = sender.state == .on }
        if sender.state == .on {
            NotificationManager.shared.requestAuthorization()
        }
    }

    @objc private func finish() {
        NSApp.stopModal()
    }

    // MARK: - Time <-> minutes-since-midnight

    private static func date(fromMinutes minutes: Int) -> Date {
        var comps = DateComponents()
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func minutes(fromDate date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
