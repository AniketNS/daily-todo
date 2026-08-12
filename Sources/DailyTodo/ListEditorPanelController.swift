import AppKit

/// One row in a list-editor panel: a static circle bullet, the item's text, and a
/// remove button. No checkbox/complete behavior — these are list entries being composed.
private final class EditableRowView: NSView {
    var onRemove: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let circle = NSImageView()
        circle.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        circle.contentTintColor = .tertiaryLabelColor
        circle.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false

        let removeButton = NSButton()
        removeButton.isBordered = false
        removeButton.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove")?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        removeButton.contentTintColor = .tertiaryLabelColor
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.target = self
        removeButton.action = #selector(removeTapped)

        addSubview(circle)
        addSubview(label)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            circle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 18),
            circle.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),

            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 18),
            removeButton.heightAnchor.constraint(equalToConstant: 18),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func removeTapped() { onRemove?() }
}

/// Rounded checklist-style editor for a list of task strings: existing items show as
/// removable rows, with an "Add item" input row at the bottom that keeps the panel open
/// after each Return so several items can be entered in one sitting. Used for both the
/// quick "Add Task" flow and editing the recurring default tasks.
final class ListEditorPanelController: NSObject {
    private var panel: FancyPanel!
    private var stack: NSStackView!
    private var inputField: NSTextField!
    private var items: [String] = []

    func run(title: String, subtitle: String, iconSymbol: String, initialItems: [String]) -> [String] {
        items = initialItems

        let panel = FancyPanel(width: 380, height: 420)
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

        let (badge, _) = FancyStyle.iconBadge(systemSymbol: iconSymbol)
        let titleLabel = FancyStyle.titleLabel(title)
        let subtitleLabel = FancyStyle.subtitleLabel(subtitle)
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

        let inputCircle = NSImageView()
        inputCircle.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        inputCircle.contentTintColor = .tertiaryLabelColor
        inputCircle.translatesAutoresizingMaskIntoConstraints = false

        let field = NSTextField()
        field.placeholderString = "Add item"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 13.5)
        field.target = self
        field.action = #selector(addItem)
        field.translatesAutoresizingMaskIntoConstraints = false
        self.inputField = field

        let inputRow = NSView()
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputRow.addSubview(inputCircle)
        inputRow.addSubview(field)
        NSLayoutConstraint.activate([
            inputCircle.leadingAnchor.constraint(equalTo: inputRow.leadingAnchor, constant: 4),
            inputCircle.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            inputCircle.widthAnchor.constraint(equalToConstant: 18),
            inputCircle.heightAnchor.constraint(equalToConstant: 18),

            field.leadingAnchor.constraint(equalTo: inputCircle.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: inputRow.trailingAnchor),
            field.topAnchor.constraint(equalTo: inputRow.topAnchor, constant: 6),
            field.bottomAnchor.constraint(equalTo: inputRow.bottomAnchor, constant: -6),
        ])

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.stack = stack

        for text in items {
            addRow(text: text, to: stack)
        }

        scrollView.documentView = stack
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])

        let doneButton = FancyStyle.primaryButton(title: "Done", target: self, action: #selector(finish))

        container.addSubview(inputRow)
        container.addSubview(separator)
        container.addSubview(scrollView)
        container.addSubview(doneButton)

        NSLayoutConstraint.activate([
            inputRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            inputRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            inputRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            separator.topAnchor.constraint(equalTo: inputRow.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -16),

            doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)

        return items
    }

    private func addRow(text: String, to stack: NSStackView) {
        let row = EditableRowView(text: text)
        row.onRemove = { [weak self, weak row] in
            guard let self, let row else { return }
            if let idx = stack.arrangedSubviews.firstIndex(of: row), idx < self.items.count {
                self.items.remove(at: idx)
            }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                row.animator().alphaValue = 0
            }, completionHandler: {
                stack.removeArrangedSubview(row)
                row.removeFromSuperview()
            })
        }
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    @objc private func addItem() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        items.append(text)
        addRow(text: text, to: stack)
        inputField.stringValue = ""
    }

    @objc private func finish() {
        NSApp.stopModal()
    }
}
