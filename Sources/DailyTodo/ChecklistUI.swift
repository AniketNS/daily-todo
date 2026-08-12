import AppKit

/// A round SF Symbol checkbox that pops with a little animation when toggled.
final class CheckboxButton: NSButton {
    private(set) var checked: Bool
    var onToggle: ((Bool) -> Void)?

    init(checked: Bool) {
        self.checked = checked
        super.init(frame: .zero)
        isBordered = false
        imagePosition = .imageOnly
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(tapped)
        setAccessibilityRole(.checkBox)
        updateImage(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        checked.toggle()
        updateImage(animated: true)
        onToggle?(checked)
    }

    func setChecked(_ value: Bool, animated: Bool) {
        guard value != checked else { return }
        checked = value
        updateImage(animated: animated)
    }

    private func updateImage(animated: Bool) {
        let symbolName = checked ? "checkmark.circle.fill" : "circle"
        let config = NSImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        contentTintColor = checked ? .controlAccentColor : .tertiaryLabelColor
        setAccessibilityValue(checked)

        guard animated else { return }
        alphaValue = 0.35
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }
    }
}

/// One row in the checklist: checkbox + task text (struck through when completed) + a
/// muted "not needed" action, styled to feel like a Teams/Loop checklist item.
final class TaskRowView: NSView {
    let taskId: String
    private let checkbox: CheckboxButton
    private let label = NSTextField(labelWithString: "")
    private let dismissButton = NSButton()
    private var isCompleted: Bool

    /// Called with the task's new status whenever the checkbox is toggled.
    var onToggleComplete: ((TaskStatus) -> Void)?
    /// Called when the user marks the task as not needed.
    var onDismiss: (() -> Void)?

    init(task: TodoTask) {
        self.taskId = task.id
        self.isCompleted = task.status == .completed
        self.checkbox = CheckboxButton(checked: task.status == .completed)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(text: task.text)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(text: String) {
        checkbox.onToggle = { [weak self] checked in
            self?.handleToggle(checked: checked)
        }

        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        applyLabelStyle(text: text, completed: isCompleted)

        dismissButton.isBordered = false
        dismissButton.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Not needed")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        dismissButton.contentTintColor = .tertiaryLabelColor
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.target = self
        dismissButton.action = #selector(dismissTapped)
        dismissButton.toolTip = "Mark as not needed"

        addSubview(checkbox)
        addSubview(label)
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 24),
            checkbox.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 18),
            dismissButton.heightAnchor.constraint(equalToConstant: 18),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])
    }

    private func handleToggle(checked: Bool) {
        isCompleted = checked
        let text = label.attributedStringValue.string

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            label.animator().alphaValue = 0.35
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.applyLabelStyle(text: text, completed: checked)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.label.animator().alphaValue = 1.0
            }
        })

        onToggleComplete?(checked ? .completed : .pending)
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }

    private func applyLabelStyle(text: String, completed: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.5, weight: completed ? .regular : .medium),
            .foregroundColor: completed ? NSColor.tertiaryLabelColor : NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        if completed {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = NSColor.tertiaryLabelColor
        }
        label.attributedStringValue = NSAttributedString(string: text, attributes: attributes)
    }
}
