import Foundation
import SwiftData

enum ExecutionSource: String {
    case scheduled
    case manual
}

enum ExecutionTaskStatus: String {
    case active
    case completed
    case archived
}

enum TemplateRecurrence: String {
    case onDemand
    case daily
    case weekly
    case monthly
    case monthEnd
    case yearly

    var label: String {
        switch self {
        case .onDemand:
            return "必要な時に開始"
        case .daily:
            return "毎日"
        case .weekly:
            return "毎週"
        case .monthly:
            return "毎月"
        case .monthEnd:
            return "毎月末"
        case .yearly:
            return "毎年"
        }
    }

    static func from(label: String) -> TemplateRecurrence {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLabel.isEmpty || trimmedLabel == "必要な時に開始" || trimmedLabel == "繰り返しなし" {
            return .onDemand
        }
        if trimmedLabel == "毎日" {
            return .daily
        }
        if trimmedLabel.hasPrefix("毎週") {
            return .weekly
        }
        if trimmedLabel == "毎月末" {
            return .monthEnd
        }
        if trimmedLabel.hasPrefix("毎月") {
            return .monthly
        }
        if trimmedLabel.hasPrefix("毎年") {
            return .yearly
        }
        return .onDemand
    }
}

@Model
final class TaskTemplate {
    @Attribute(.unique) var id: UUID
    var title: String
    var cadenceLabel: String
    var category: String?
    var detail: String
    var iconName: String
    var tintName: String
    var recurrenceRawValue: String = TemplateRecurrence.onDemand.rawValue
    var scheduledWeekday: Int?
    var scheduledDay: Int?
    var scheduledMonth: Int?
    var advanceDays: Int = 0
    var notificationHour: Int?
    var notificationMinute: Int?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TemplateStep.template) var steps: [TemplateStep]
    @Relationship(deleteRule: .nullify, inverse: \ExecutionTask.template) var executionTasks: [ExecutionTask]

    init(
        id: UUID = UUID(),
        title: String,
        cadenceLabel: String,
        category: String? = nil,
        detail: String,
        iconName: String,
        tintName: String,
        recurrence: TemplateRecurrence? = nil,
        scheduledWeekday: Int? = nil,
        scheduledDay: Int? = nil,
        scheduledMonth: Int? = nil,
        advanceDays: Int = 0,
        notificationHour: Int? = nil,
        notificationMinute: Int? = nil,
        createdAt: Date = .now,
        steps: [TemplateStep] = []
    ) {
        self.id = id
        self.title = title
        self.cadenceLabel = cadenceLabel
        self.category = category
        self.detail = detail
        self.iconName = iconName
        self.tintName = tintName
        self.recurrenceRawValue = (recurrence ?? TemplateRecurrence.from(label: cadenceLabel)).rawValue
        self.scheduledWeekday = scheduledWeekday
        self.scheduledDay = scheduledDay
        self.scheduledMonth = scheduledMonth
        self.advanceDays = advanceDays
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.createdAt = createdAt
        self.steps = steps
        self.executionTasks = []
    }

    var sortedSteps: [TemplateStep] {
        steps.sorted { $0.sortIndex < $1.sortIndex }
    }

    var recurrence: TemplateRecurrence {
        get {
            let storedRecurrence = TemplateRecurrence(rawValue: recurrenceRawValue) ?? .onDemand
            let labelRecurrence = TemplateRecurrence.from(label: cadenceLabel)
            if storedRecurrence == .onDemand && labelRecurrence != .onDemand {
                return labelRecurrence
            }
            return storedRecurrence
        }
        set {
            recurrenceRawValue = newValue.rawValue
            cadenceLabel = newValue.label
        }
    }
}

@Model
final class TemplateStep {
    @Attribute(.unique) var id: UUID
    var title: String
    var parentID: UUID?
    var sortIndex: Int
    var template: TaskTemplate?

    init(id: UUID = UUID(), title: String, parentID: UUID? = nil, sortIndex: Int) {
        self.id = id
        self.title = title
        self.parentID = parentID
        self.sortIndex = sortIndex
    }
}

@Model
final class ExecutionTask {
    @Attribute(.unique) var id: UUID
    var templateID: UUID?
    var templateTitle: String?
    var title: String
    var cadenceLabel: String
    var category: String?
    var iconName: String
    var tintName: String
    var scheduledDate: Date
    var startDate: Date = Date.now
    var dueDate: Date?
    var sourceRawValue: String = ExecutionSource.scheduled.rawValue
    var statusRawValue: String = ExecutionTaskStatus.active.rawValue
    var createdAt: Date
    var completedAt: Date?
    var isExpanded: Bool
    var template: TaskTemplate?
    @Relationship(deleteRule: .cascade, inverse: \ExecutionStep.executionTask) var steps: [ExecutionStep]

    init(
        id: UUID = UUID(),
        templateID: UUID? = nil,
        templateTitle: String? = nil,
        title: String,
        cadenceLabel: String,
        category: String? = nil,
        iconName: String,
        tintName: String,
        scheduledDate: Date,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        source: ExecutionSource = .scheduled,
        status: ExecutionTaskStatus = .active,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        template: TaskTemplate? = nil,
        steps: [ExecutionStep] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.templateID = templateID
        self.templateTitle = templateTitle
        self.title = title
        self.cadenceLabel = cadenceLabel
        self.category = category
        self.iconName = iconName
        self.tintName = tintName
        self.scheduledDate = scheduledDate
        self.startDate = startDate ?? scheduledDate
        self.dueDate = dueDate
        self.sourceRawValue = source.rawValue
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isExpanded = isExpanded
        self.template = template
        self.steps = steps
    }

    var sortedSteps: [ExecutionStep] {
        steps.sorted { $0.sortIndex < $1.sortIndex }
    }

    var completedCount: Int {
        ProgressService.completedCount(for: steps)
    }

    var totalCount: Int {
        ProgressService.totalCount(for: steps)
    }

    var progress: Double {
        ProgressService.progress(for: steps)
    }

    var subtitle: String {
        ProgressService.subtitle(cadenceLabel: cadenceLabel, category: category, steps: steps)
    }

    var source: ExecutionSource {
        get {
            ExecutionSource(rawValue: sourceRawValue) ?? .scheduled
        }
        set {
            sourceRawValue = newValue.rawValue
        }
    }

    var status: ExecutionTaskStatus {
        get {
            ExecutionTaskStatus(rawValue: statusRawValue) ?? .active
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }
}

@Model
final class ExecutionStep {
    @Attribute(.unique) var id: UUID
    var title: String
    var parentID: UUID?
    var sortIndex: Int
    var isCompleted: Bool
    var completedAt: Date?
    var executionTask: ExecutionTask?

    init(
        id: UUID = UUID(),
        title: String,
        parentID: UUID? = nil,
        sortIndex: Int,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.parentID = parentID
        self.sortIndex = sortIndex
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
