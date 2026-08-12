import AppKit

enum MorningResult {
    case saved([String])
    case snoozed
}

enum Prompts {

    static func showMorningPrompt(defaults: [String]) -> MorningResult {
        MorningPanelController().run(defaults: defaults)
    }

    /// Reviews every task still pending at the evening check-in in a single panel:
    /// tick to complete, or push to tomorrow / mark not needed per row. Returns the
    /// snooze duration (minutes) picked at the bottom, or nil if none was picked.
    static func showEveningReview(
        tasks: [TodoTask], onAction: @escaping (String, EveningRowAction) -> Void
    ) -> Int? {
        EveningReviewPanelController().run(tasks: tasks, onAction: onAction)
    }

    /// Add one or more tasks for today in a single sitting; the panel stays open after
    /// each Return so several items can be entered before closing.
    static func promptForNewTasks() -> [String] {
        let controller = ListEditorPanelController()
        return controller.run(
            title: "Add Tasks",
            subtitle: "Press Return to add each one, then Done when finished.",
            iconSymbol: "plus.circle.fill",
            initialItems: []
        )
    }

    static func promptForDefaults(current: [String]) -> [String] {
        let controller = ListEditorPanelController()
        return controller.run(
            title: "Default Tasks",
            subtitle: "Added automatically every weekday morning, even if completed the day before.",
            iconSymbol: "repeat.circle.fill",
            initialItems: current
        )
    }

    /// Checklist viewer for today's tasks, usable any time (not just at the scheduled prompts).
    /// Tick a task to complete it (struck through, Teams/Loop style) or mark it not needed.
    static func showTaskList(
        tasks: [TodoTask], onChange: @escaping (String, TaskStatus) -> Void, autoDismissAfter: TimeInterval? = nil
    ) {
        ChecklistPanelController().run(tasks: tasks, onChange: onChange, autoDismissAfter: autoDismissAfter)
    }
}
