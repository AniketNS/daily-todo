import AppKit

/// NSStackView isn't flipped by default, so as a scroll view's documentView it settles
/// at the bottom when its content is shorter than the visible area. Flipping it pins
/// rows to the top instead, like a normal list.
final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

/// A borderless, blurred, rounded-corner "card" window used for all DailyTodo prompts,
/// so the app reads as one consistent modern design instead of stock NSAlert boxes.
final class FancyPanel: NSPanel {
    let cardView = NSVisualEffectView()
    var onCancel: (() -> Void)?
    private var autoDismissTimer: Timer?

    convenience init(width: CGFloat, height: CGFloat) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        level = .modalPanel

        cardView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        cardView.autoresizingMask = [.width, .height]
        cardView.material = .popover
        cardView.blendingMode = .behindWindow
        cardView.state = .active
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 18
        cardView.layer?.masksToBounds = true
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor

        contentView = cardView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Auto-closes the panel if the user hasn't already dismissed it. Uses `.common`
    /// run loop mode since a plain `Timer` won't fire while `NSApp.runModal` is active
    /// (that runs the loop in `.modalPanel` mode, not `.default`).
    func scheduleAutoDismiss(after seconds: TimeInterval, action: @escaping () -> Void) {
        autoDismissTimer?.invalidate()
        let timer = Timer(timeInterval: seconds, repeats: false) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        autoDismissTimer = timer
    }

    func cancelAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }
}

/// Shared button/label styling so every prompt looks like part of the same app.
enum FancyStyle {
    static func iconBadge(systemSymbol: String) -> (badge: NSView, imageView: NSImageView) {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 10
        badge.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        imageView.image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        imageView.contentTintColor = .controlAccentColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(imageView)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 36),
            badge.heightAnchor.constraint(equalToConstant: 36),
            imageView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])

        return (badge, imageView)
    }

    static func titleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func subtitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func primaryButton(title: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func secondaryButton(title: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func chipButton(title: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func closeButton(target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: target, action: action)
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .regular))
        button.contentTintColor = .tertiaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
