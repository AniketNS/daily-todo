import AppKit

/// Shows today's tasks as a checklist: tick a box to complete a task (with a
/// Teams/Loop-style strikethrough), or dismiss it as not needed. Replaces the old
/// one-alert-per-task flow with a single scrollable card.
final class ChecklistPanelController: NSObject {
    private var panel: FancyPanel!
    private var stack: NSStackView!
    private var onChange: (String, TaskStatus) -> Void = { _, _ in }

    /// `autoDismissAfter` is only set for the automatic hourly pop-up — the menu's
    /// manually-opened "Today's Tasks" stays open until the user closes it.
    func run(tasks: [TodoTask], onChange: @escaping (String, TaskStatus) -> Void, autoDismissAfter: TimeInterval? = nil) {
        self.onChange = onChange
        let visibleTasks = tasks.filter { $0.status != .dismissed }

        let panel = FancyPanel(width: 380, height: visibleTasks.isEmpty ? 240 : 470)
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

        let (badge, _) = FancyStyle.iconBadge(systemSymbol: "checklist")
        let titleLabel = FancyStyle.titleLabel("Today's Tasks")
        let subtitleLabel = FancyStyle.subtitleLabel(todayDateString())
        let closeButton = FancyStyle.closeButton(target: self, action: #selector(finish))

        container.addSubview(badge)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        container.addSubview(closeButton)
        [titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

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

        if visibleTasks.isEmpty {
            let emptyLabel = FancyStyle.subtitleLabel("No tasks recorded for today yet.")
            emptyLabel.alignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            let doneButton = FancyStyle.primaryButton(title: "OK", target: self, action: #selector(finish))
            container.addSubview(emptyLabel)
            container.addSubview(doneButton)
            NSLayoutConstraint.activate([
                emptyLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
                emptyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                emptyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

                doneButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 24),
                doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        } else {
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
            self.stack = stack

            for task in visibleTasks {
                addRow(for: task, to: stack)
            }

            scrollView.documentView = stack
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
                stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            ])

            let doneButton = FancyStyle.primaryButton(title: "Done", target: self, action: #selector(finish))
            container.addSubview(scrollView)
            container.addSubview(doneButton)

            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -16),

                doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        if let autoDismissAfter {
            panel.scheduleAutoDismiss(after: autoDismissAfter) { [weak self] in self?.finish() }
        }
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
    }

    private func addRow(for task: TodoTask, to stack: NSStackView) {
        let row = TaskRowView(task: task)
        row.onToggleComplete = { [weak self] status in
            self?.onChange(task.id, status)
        }
        row.onDismiss = { [weak self, weak row] in
            guard let self, let row else { return }
            self.onChange(task.id, .dismissed)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                row.animator().alphaValue = 0
            }, completionHandler: {
                stack.removeArrangedSubview(row)
                row.removeFromSuperview()
            })
        }
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    @objc private func finish() {
        panel.cancelAutoDismiss()
        NSApp.stopModal()
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
}
