import AppKit

enum EveningRowAction {
    case completed, tomorrow, notNeeded
}

/// One row in the evening review: tick to complete, or push to tomorrow / mark not
/// needed via the trailing icon buttons. Rows resolve and disappear individually.
private final class EveningRowView: NSView {
    var onComplete: (() -> Void)?
    var onTomorrow: (() -> Void)?
    var onNotNeeded: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(text: text)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(text: String) {
        let checkbox = CheckboxButton(checked: false)
        checkbox.onToggle = { [weak self] _ in self?.onComplete?() }

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false

        let tomorrowButton = NSButton()
        tomorrowButton.isBordered = false
        tomorrowButton.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: "Move to tomorrow")?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        tomorrowButton.contentTintColor = .secondaryLabelColor
        tomorrowButton.translatesAutoresizingMaskIntoConstraints = false
        tomorrowButton.target = self
        tomorrowButton.action = #selector(tomorrowTapped)
        tomorrowButton.toolTip = "Move to tomorrow"

        let dismissButton = NSButton()
        dismissButton.isBordered = false
        dismissButton.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Not needed")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        dismissButton.contentTintColor = .tertiaryLabelColor
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.target = self
        dismissButton.action = #selector(dismissTapped)
        dismissButton.toolTip = "Not needed"

        addSubview(checkbox)
        addSubview(label)
        addSubview(tomorrowButton)
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 24),
            checkbox.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: tomorrowButton.leadingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            tomorrowButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            tomorrowButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            tomorrowButton.widthAnchor.constraint(equalToConstant: 18),
            tomorrowButton.heightAnchor.constraint(equalToConstant: 18),

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 18),
            dismissButton.heightAnchor.constraint(equalToConstant: 18),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])
    }

    @objc private func tomorrowTapped() { onTomorrow?() }
    @objc private func dismissTapped() { onNotNeeded?() }
}

/// Reviews every task still pending at the evening check-in in one panel instead of one
/// alert per task: tick to complete, or push to tomorrow / mark not needed. Closes on
/// its own once every row is resolved.
final class EveningReviewPanelController: NSObject {
    private var panel: FancyPanel!
    private var onAction: (String, EveningRowAction) -> Void = { _, _ in }
    private var chosenSnoozeMinutes: Int?

    /// Shows the review panel and returns the snooze duration the user picked at the
    /// bottom (5/10/20 min), or nil if they closed without picking one (caller should
    /// fall back to its own default).
    func run(tasks: [TodoTask], onAction: @escaping (String, EveningRowAction) -> Void) -> Int? {
        guard !tasks.isEmpty else { return nil }
        self.onAction = onAction

        let panel = FancyPanel(width: 380, height: 510)
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

        let (badge, _) = FancyStyle.iconBadge(systemSymbol: "exclamationmark.circle.fill")
        let titleLabel = FancyStyle.titleLabel("Still Pending")
        let subtitleLabel = FancyStyle.subtitleLabel("These aren't marked done yet. Wrap them up or push to tomorrow.")
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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for task in tasks {
            addRow(id: task.id, text: task.text, to: stack)
        }

        scrollView.documentView = stack
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])

        let snoozeLabel = FancyStyle.subtitleLabel("Remind me again in:")
        snoozeLabel.font = NSFont.systemFont(ofSize: 11)

        let snooze5 = FancyStyle.chipButton(title: "5 min", target: self, action: #selector(snoozeTapped(_:)))
        let snooze10 = FancyStyle.chipButton(title: "10 min", target: self, action: #selector(snoozeTapped(_:)))
        let snooze20 = FancyStyle.chipButton(title: "20 min", target: self, action: #selector(snoozeTapped(_:)))
        snooze5.tag = 5
        snooze10.tag = 10
        snooze20.tag = 20

        let snoozeRow = NSStackView(views: [snooze5, snooze10, snooze20])
        snoozeRow.orientation = .horizontal
        snoozeRow.spacing = 8
        snoozeRow.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = FancyStyle.primaryButton(title: "Done", target: self, action: #selector(finish))
        container.addSubview(scrollView)
        container.addSubview(snoozeLabel)
        container.addSubview(snoozeRow)
        container.addSubview(doneButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: snoozeLabel.topAnchor, constant: -12),

            snoozeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            snoozeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            snoozeRow.topAnchor.constraint(equalTo: snoozeLabel.bottomAnchor, constant: 6),
            snoozeRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            snoozeRow.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -14),

            doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.scheduleAutoDismiss(after: 60) { [weak self] in self?.finish() }
        NSApp.runModal(for: panel)
        panel.orderOut(nil)

        return chosenSnoozeMinutes
    }

    private func addRow(id: String, text: String, to stack: NSStackView) {
        let row = EveningRowView(text: text)
        row.onComplete = { [weak self] in self?.resolve(id, action: .completed, row: row, stack: stack) }
        row.onTomorrow = { [weak self] in self?.resolve(id, action: .tomorrow, row: row, stack: stack) }
        row.onNotNeeded = { [weak self] in self?.resolve(id, action: .notNeeded, row: row, stack: stack) }
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func resolve(_ id: String, action: EveningRowAction, row: NSView, stack: NSStackView) {
        onAction(id, action)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            row.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
            if stack.arrangedSubviews.isEmpty {
                self?.finish()
            }
        })
    }

    @objc private func snoozeTapped(_ sender: NSButton) {
        chosenSnoozeMinutes = sender.tag
        finish()
    }

    @objc private func finish() {
        panel.cancelAutoDismiss()
        NSApp.stopModal()
    }
}
