import AppKit

/// The fancy replacement for the old NSAlert-based "Today's Tasks" entry prompt.
final class MorningPanelController: NSObject {
    private var panel: FancyPanel!
    private var textView: NSTextView!
    private var result: MorningResult = .snoozed

    func run(defaults: [String]) -> MorningResult {
        let panel = FancyPanel(width: 380, height: 350)
        self.panel = panel
        panel.onCancel = { [weak self] in self?.snooze() }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        panel.cardView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: panel.cardView.topAnchor, constant: 22),
            container.leadingAnchor.constraint(equalTo: panel.cardView.leadingAnchor, constant: 22),
            container.trailingAnchor.constraint(equalTo: panel.cardView.trailingAnchor, constant: -22),
            container.bottomAnchor.constraint(equalTo: panel.cardView.bottomAnchor, constant: -20),
        ])

        let (badge, _) = FancyStyle.iconBadge(systemSymbol: "sun.max.fill")
        let titleLabel = FancyStyle.titleLabel("Today's Tasks")
        let subtitleLabel = FancyStyle.subtitleLabel(
            "One task per line. Clear the box and click Save to record no tasks today."
        )
        [titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 10
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.6).cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.string = defaults.joined(separator: "\n")
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        self.textView = textView

        scrollView.documentView = textView

        let saveButton = FancyStyle.primaryButton(title: "Save", target: self, action: #selector(save))
        let snoozeButton = FancyStyle.secondaryButton(title: "Snooze 15 min", target: self, action: #selector(snooze))
        let buttonRow = NSStackView(views: [snoozeButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        [badge, titleLabel, subtitleLabel].forEach { container.addSubview($0) }
        container.addSubview(scrollView)
        container.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            titleLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor, constant: -7),
            titleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -16),

            buttonRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        panel.scheduleAutoDismiss(after: 60) { [weak self] in self?.snooze() }
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }

    @objc private func save() {
        panel.cancelAutoDismiss()
        let lines = textView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        result = .saved(lines)
        NSApp.stopModal()
    }

    @objc private func snooze() {
        panel.cancelAutoDismiss()
        result = .snoozed
        NSApp.stopModal()
    }
}
