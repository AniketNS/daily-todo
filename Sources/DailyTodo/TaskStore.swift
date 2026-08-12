import Foundation

struct TodoTask: Codable, Identifiable, Equatable {
    let id: String
    var text: String
    var status: TaskStatus
}

enum TaskStatus: String, Codable {
    case pending, completed, dismissed
}

struct DayState: Codable {
    var morningDone: Bool = false
    var lastMorningPromptAt: Date? = nil
    var nextEveningPromptAt: Date? = nil
    var lastHourlyPromptAt: Date? = nil
}

struct AppState: Codable {
    var days: [String: DayState] = [:]
}

final class TaskStore {
    static let shared = TaskStore()

    private let appSupportDir: URL
    private let tasksFile: URL
    private let defaultsFile: URL
    private let stateFile: URL

    private var tasksByDate: [String: [TodoTask]] = [:]
    private var state: AppState = AppState()
    private var defaults: [String] = ["Fill timesheet"]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        return f
    }()

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        appSupportDir = base.appendingPathComponent("DailyTodo", isDirectory: true)
        try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        tasksFile = appSupportDir.appendingPathComponent("tasks.json")
        defaultsFile = appSupportDir.appendingPathComponent("defaults.json")
        stateFile = appSupportDir.appendingPathComponent("state.json")
        load()
    }

    // MARK: - Date helpers

    func dateKey(for date: Date = Date()) -> String {
        dateFormatter.string(from: date)
    }

    private func dateKey(daysFromToday offset: Int) -> String {
        let target = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        return dateFormatter.string(from: target)
    }

    // MARK: - Persistence

    private func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: tasksFile),
           let decoded = try? dec.decode([String: [TodoTask]].self, from: data) {
            tasksByDate = decoded
        }
        if let data = try? Data(contentsOf: stateFile),
           let decoded = try? dec.decode(AppState.self, from: data) {
            state = decoded
        }
        if let data = try? Data(contentsOf: defaultsFile),
           let decoded = try? dec.decode([String].self, from: data) {
            defaults = decoded
        } else {
            saveDefaults()
        }
    }

    private func saveTasks() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(tasksByDate) {
            try? data.write(to: tasksFile, options: .atomic)
        }
    }

    private func saveState() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(state) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }

    private func saveDefaults() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(defaults) {
            try? data.write(to: defaultsFile, options: .atomic)
        }
    }

    // MARK: - Defaults

    func defaultTasks() -> [String] {
        defaults
    }

    func setDefaultTasks(_ texts: [String]) {
        defaults = texts
        saveDefaults()
    }

    /// What to pre-fill the morning prompt with: existing pending tasks for today if any
    /// interaction already happened, otherwise the configured defaults.
    func defaultTasksOrPendingForToday() -> [String] {
        let key = dateKey()
        if let existing = tasksByDate[key], !existing.isEmpty {
            return existing.filter { $0.status == .pending }.map { $0.text }
        }
        return defaults
    }

    // MARK: - Tasks

    func tasksForToday() -> [TodoTask] {
        tasksByDate[dateKey()] ?? []
    }

    func pendingTasksForToday() -> [TodoTask] {
        tasksForToday().filter { $0.status == .pending }
    }

    /// Replaces today's full task list with a fresh set of pending tasks (used by the morning prompt).
    func saveTodayTasks(_ texts: [String]) {
        let key = dateKey()
        let tasks = texts.map { TodoTask(id: UUID().uuidString, text: $0, status: .pending) }
        tasksByDate[key] = tasks
        saveTasks()
    }

    func addTask(text: String, dayOffset: Int = 0) {
        let key = dateKey(daysFromToday: dayOffset)
        var list = tasksByDate[key] ?? []
        list.append(TodoTask(id: UUID().uuidString, text: text, status: .pending))
        tasksByDate[key] = list
        saveTasks()
    }

    /// Adds any default task that isn't already present in today's list (in any status),
    /// so recurring tasks reappear each new day regardless of yesterday's outcome.
    /// Idempotent and safe to call repeatedly through the day.
    func ensureDefaultTasksForToday() {
        let key = dateKey()
        var list = tasksByDate[key] ?? []
        let existingTexts = Set(list.map { $0.text })
        var didChange = false
        for text in defaults where !existingTexts.contains(text) {
            list.append(TodoTask(id: UUID().uuidString, text: text, status: .pending))
            didChange = true
        }
        guard didChange else { return }
        tasksByDate[key] = list
        saveTasks()
    }

    func updateTaskStatus(id: String, status: TaskStatus) {
        let key = dateKey()
        guard var list = tasksByDate[key] else { return }
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].status = status
            tasksByDate[key] = list
            saveTasks()
        }
    }

    func moveTaskToTomorrow(id: String) {
        let key = dateKey()
        guard var list = tasksByDate[key] else { return }
        guard let idx = list.firstIndex(where: { $0.id == id }) else { return }
        let text = list[idx].text
        list[idx].status = .dismissed
        tasksByDate[key] = list
        addTask(text: text, dayOffset: 1)
        saveTasks()
    }

    // MARK: - Day state (morning/evening prompt bookkeeping)

    func isMorningDone() -> Bool {
        state.days[dateKey()]?.morningDone ?? false
    }

    func markMorningDone() {
        var day = state.days[dateKey()] ?? DayState()
        day.morningDone = true
        state.days[dateKey()] = day
        saveState()
    }

    func lastMorningPromptAt() -> Date? {
        state.days[dateKey()]?.lastMorningPromptAt
    }

    func setLastMorningPromptAt(_ date: Date) {
        var day = state.days[dateKey()] ?? DayState()
        day.lastMorningPromptAt = date
        state.days[dateKey()] = day
        saveState()
    }

    func nextEveningPromptAt() -> Date? {
        state.days[dateKey()]?.nextEveningPromptAt
    }

    func setNextEveningPromptAt(_ date: Date) {
        var day = state.days[dateKey()] ?? DayState()
        day.nextEveningPromptAt = date
        state.days[dateKey()] = day
        saveState()
    }

    func lastHourlyPromptAt() -> Date? {
        state.days[dateKey()]?.lastHourlyPromptAt
    }

    func setLastHourlyPromptAt(_ date: Date) {
        var day = state.days[dateKey()] ?? DayState()
        day.lastHourlyPromptAt = date
        state.days[dateKey()] = day
        saveState()
    }
}
