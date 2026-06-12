import Foundation
import SwiftData
import UserNotifications

struct TemplateBackupDTO: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var templates: [TaskTemplateDTO]
}

struct TaskTemplateDTO: Codable {
    var id: UUID
    var title: String
    var cadenceLabel: String
    var category: String?
    var detail: String
    var iconName: String
    var tintName: String
    var recurrenceRawValue: String
    var scheduledWeekday: Int?
    var scheduledDay: Int?
    var scheduledMonth: Int?
    var advanceDays: Int
    var notificationHour: Int?
    var notificationMinute: Int?
    var steps: [TemplateStepDTO]
}

struct TemplateStepDTO: Codable {
    var id: UUID
    var title: String
    var parentID: UUID?
    var sortIndex: Int
}

enum TemplateImportExportService {
    static func exportTemplates(_ templates: [TaskTemplate]) throws -> Data {
        let backup = TemplateBackupDTO(
            schemaVersion: 1,
            exportedAt: Date(),
            templates: templates
                .sorted { $0.createdAt < $1.createdAt }
                .map { template in
                    TaskTemplateDTO(
                        id: template.id,
                        title: template.title,
                        cadenceLabel: template.cadenceLabel,
                        category: template.category,
                        detail: template.detail,
                        iconName: template.iconName,
                        tintName: template.tintName,
                        recurrenceRawValue: template.recurrence.rawValue,
                        scheduledWeekday: template.scheduledWeekday,
                        scheduledDay: template.scheduledDay,
                        scheduledMonth: template.scheduledMonth,
                        advanceDays: template.advanceDays,
                        notificationHour: template.notificationHour,
                        notificationMinute: template.notificationMinute,
                        steps: template.sortedSteps.map { step in
                            TemplateStepDTO(
                                id: step.id,
                                title: step.title,
                                parentID: step.parentID,
                                sortIndex: step.sortIndex
                            )
                        }
                    )
                }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    @MainActor
    @discardableResult
    static func importTemplates(from data: Data, into context: ModelContext) throws -> [TaskTemplate] {
        let backup = try decodedBackup(from: data)
        let existingTitles = try context.fetch(FetchDescriptor<TaskTemplate>()).map(\.title)
        var reservedTitles = Set(existingTitles)
        var importedTemplates: [TaskTemplate] = []

        for templateDTO in backup.templates {
            var stepIDMap: [UUID: UUID] = [:]
            for stepDTO in templateDTO.steps where stepIDMap[stepDTO.id] == nil {
                stepIDMap[stepDTO.id] = UUID()
            }
            let importedSteps = templateDTO.steps
                .sorted { $0.sortIndex < $1.sortIndex }
                .enumerated()
                .map { index, stepDTO in
                    TemplateStep(
                        id: stepIDMap[stepDTO.id] ?? UUID(),
                        title: stepDTO.title,
                        parentID: stepDTO.parentID.flatMap { stepIDMap[$0] },
                        sortIndex: index
                    )
                }

            let uniqueTitle = uniqueImportedTitle(for: templateDTO.title, reservedTitles: &reservedTitles)
            let template = TaskTemplate(
                id: UUID(),
                title: uniqueTitle,
                cadenceLabel: templateDTO.cadenceLabel,
                category: templateDTO.category,
                detail: templateDTO.detail,
                iconName: templateDTO.iconName,
                tintName: templateDTO.tintName,
                recurrence: TemplateRecurrence(rawValue: templateDTO.recurrenceRawValue) ?? TemplateRecurrence.from(label: templateDTO.cadenceLabel),
                scheduledWeekday: templateDTO.scheduledWeekday,
                scheduledDay: templateDTO.scheduledDay,
                scheduledMonth: templateDTO.scheduledMonth,
                advanceDays: templateDTO.advanceDays,
                notificationHour: templateDTO.notificationHour,
                notificationMinute: templateDTO.notificationMinute,
                createdAt: Date(),
                steps: importedSteps
            )

            context.insert(template)
            TemplateScheduleService.normalizeScheduleFields(for: template)
            importedTemplates.append(template)
        }

        return importedTemplates
    }

    private static func decodedBackup(from data: Data) throws -> TemplateBackupDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let backup = try? decoder.decode(TemplateBackupDTO.self, from: data) {
            return backup
        }

        let templates = try decoder.decode([TaskTemplateDTO].self, from: data)
        return TemplateBackupDTO(schemaVersion: 1, exportedAt: Date(), templates: templates)
    }

    private static func uniqueImportedTitle(for title: String, reservedTitles: inout Set<String>) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = trimmedTitle.isEmpty ? "インポートしたテンプレート" : trimmedTitle

        guard reservedTitles.contains(baseTitle) else {
            reservedTitles.insert(baseTitle)
            return baseTitle
        }

        var suffix = 1
        while true {
            let candidate = "\(baseTitle)（インポート\(suffix)）"
            if !reservedTitles.contains(candidate) {
                reservedTitles.insert(candidate)
                return candidate
            }
            suffix += 1
        }
    }
}

enum SampleDataSeeder {
    private static let sampleTemplateTitle = "月末請求業務"
    private static let didSeedSampleTemplateKey = "didSeedSampleTemplate"

    @MainActor
    static func ensureSampleTemplate(in context: ModelContext) throws -> TaskTemplate? {
        if let template = try existingTemplate(in: context) {
            UserDefaults.standard.set(true, forKey: didSeedSampleTemplateKey)
            applySampleHierarchy(to: template)
            return template
        }

        guard !UserDefaults.standard.bool(forKey: didSeedSampleTemplateKey) else {
            return nil
        }

        let spotLogStep = TemplateStep(title: "SpotLog確認", sortIndex: 0)
        let invoiceStep = TemplateStep(title: "請求書PDF作成", sortIndex: 2)
        let template = TaskTemplate(
            title: sampleTemplateTitle,
            cadenceLabel: "毎月25日",
            category: "仕事",
            detail: "請求書・領収書作成から提出前チェックまでの汎用業務例",
            iconName: "doc.text",
            tintName: "teal",
            recurrence: .monthly,
            scheduledDay: 25,
            notificationHour: 9,
            notificationMinute: 0,
            steps: [
                spotLogStep,
                TemplateStep(title: "対象データを確認", parentID: spotLogStep.id, sortIndex: 1),
                invoiceStep,
                TemplateStep(title: "領収書PDF作成", parentID: invoiceStep.id, sortIndex: 3),
                TemplateStep(title: "提出前チェック", sortIndex: 4)
            ]
        )
        context.insert(template)
        UserDefaults.standard.set(true, forKey: didSeedSampleTemplateKey)
        return template
    }

    private static func existingTemplate(in context: ModelContext) throws -> TaskTemplate? {
        let title = sampleTemplateTitle
        var descriptor = FetchDescriptor<TaskTemplate>(
            predicate: #Predicate { template in
                template.title == title
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func applySampleHierarchy(to template: TaskTemplate) {
        template.recurrenceRawValue = TemplateRecurrence.monthly.rawValue
        template.cadenceLabel = "毎月25日"
        template.scheduledDay = 25
        template.notificationHour = template.notificationHour ?? 9
        template.notificationMinute = template.notificationMinute ?? 0

        let stepsByTitle = Dictionary(grouping: template.steps, by: \.title)
        let spotLogStep = stepsByTitle["SpotLog確認"]?.first
        let invoiceStep = stepsByTitle["請求書PDF作成"]?.first
        stepsByTitle["対象患者を確認"]?.forEach { $0.title = "対象データを確認" }

        stepsByTitle["SpotLog確認"]?.forEach { $0.parentID = nil }
        let refreshedStepsByTitle = Dictionary(grouping: template.steps, by: \.title)
        refreshedStepsByTitle["対象データを確認"]?.forEach { $0.parentID = spotLogStep?.id }
        stepsByTitle["請求書PDF作成"]?.forEach { $0.parentID = nil }
        stepsByTitle["領収書PDF作成"]?.forEach { $0.parentID = invoiceStep?.id }
        stepsByTitle["提出前チェック"]?.forEach { $0.parentID = nil }
    }
}

enum TemplateScheduleService {
    static func prepareTemplateSchedules(in context: ModelContext, calendar: Calendar = .current) throws {
        let descriptor = FetchDescriptor<TaskTemplate>()
        let templates = try context.fetch(descriptor)

        for template in templates {
            normalizeScheduleFields(for: template, calendar: calendar)
        }
    }

    static func normalizeScheduleFields(for template: TaskTemplate, referenceDate: Date = Date(), calendar: Calendar = .current) {
        let recurrence = template.recurrence
        template.recurrenceRawValue = recurrence.rawValue

        switch recurrence {
        case .onDemand:
            template.scheduledWeekday = nil
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .daily:
            template.scheduledWeekday = nil
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .weekly:
            template.scheduledWeekday = template.scheduledWeekday ?? parsedWeekday(from: template.cadenceLabel) ?? calendar.component(.weekday, from: referenceDate)
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .monthly:
            template.scheduledDay = template.scheduledDay ?? parsedDay(from: template.cadenceLabel) ?? calendar.component(.day, from: referenceDate)
            template.scheduledWeekday = nil
            template.scheduledMonth = nil
        case .monthEnd:
            template.scheduledWeekday = nil
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .yearly:
            let parsedMonthDay = parsedMonthDay(from: template.cadenceLabel)
            template.scheduledMonth = template.scheduledMonth ?? parsedMonthDay?.month ?? calendar.component(.month, from: referenceDate)
            template.scheduledDay = template.scheduledDay ?? parsedMonthDay?.day ?? calendar.component(.day, from: referenceDate)
            template.scheduledWeekday = nil
        }
    }

    static func nextOccurrenceDate(
        for template: TaskTemplate,
        from date: Date = Date(),
        searchLimitDays: Int = 370,
        calendar: Calendar = .current
    ) -> Date? {
        guard template.recurrence != .onDemand else { return nil }

        let startDate = DateHelpers.startOfDay(for: date, calendar: calendar)
        for offset in 0...searchLimitDays {
            guard let candidateDate = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            if occurs(template: template, on: candidateDate, referenceDate: date, calendar: calendar) {
                return candidateDate
            }
        }

        return nil
    }

    static func occurs(
        template: TaskTemplate,
        on date: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        switch template.recurrence {
        case .onDemand:
            return false
        case .daily:
            return true
        case .weekly:
            let weekday = template.scheduledWeekday ?? parsedWeekday(from: template.cadenceLabel) ?? calendar.component(.weekday, from: referenceDate)
            return weekday == calendar.component(.weekday, from: date)
        case .monthly:
            let scheduledDay = template.scheduledDay ?? parsedDay(from: template.cadenceLabel) ?? calendar.component(.day, from: referenceDate)
            return scheduledDay == calendar.component(.day, from: date)
        case .monthEnd:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return calendar.component(.month, from: tomorrow) != calendar.component(.month, from: date)
        case .yearly:
            let parsedMonthDay = parsedMonthDay(from: template.cadenceLabel)
            let scheduledMonth = template.scheduledMonth ?? parsedMonthDay?.month ?? calendar.component(.month, from: referenceDate)
            let scheduledDay = template.scheduledDay ?? parsedMonthDay?.day ?? calendar.component(.day, from: referenceDate)
            return scheduledMonth == calendar.component(.month, from: date)
                && scheduledDay == calendar.component(.day, from: date)
        }
    }

    private static func parsedWeekday(from label: String) -> Int? {
        if label.contains("日曜") || label.contains("日曜日") {
            return 1
        }
        if label.contains("月曜") || label.contains("月曜日") {
            return 2
        }
        if label.contains("火曜") || label.contains("火曜日") {
            return 3
        }
        if label.contains("水曜") || label.contains("水曜日") {
            return 4
        }
        if label.contains("木曜") || label.contains("木曜日") {
            return 5
        }
        if label.contains("金曜") || label.contains("金曜日") {
            return 6
        }
        if label.contains("土曜") || label.contains("土曜日") {
            return 7
        }
        return nil
    }

    private static func parsedDay(from label: String) -> Int? {
        let digits = label.filter(\.isNumber)
        guard let day = Int(digits), (1...31).contains(day) else { return nil }
        return day
    }

    private static func parsedMonthDay(from label: String) -> (month: Int, day: Int)? {
        let pattern = #"(\d{1,2})月(\d{1,2})日"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
            match.numberOfRanges == 3,
            let monthRange = Range(match.range(at: 1), in: label),
            let dayRange = Range(match.range(at: 2), in: label),
            let month = Int(label[monthRange]),
            let day = Int(label[dayRange]),
            (1...12).contains(month),
            (1...31).contains(day)
        else {
            return nil
        }
        return (month, day)
    }
}

enum ScheduledTaskGenerationService {
    private static let lastGenerationCheckDateKey = "lastScheduledTaskGenerationCheckDate"
    private static let safeBackfillDays = 30

    @discardableResult
    static func generateDueTasks(upTo date: Date = Date(), in context: ModelContext, calendar: Calendar = .current) throws -> [ExecutionTask] {
        let descriptor = FetchDescriptor<TaskTemplate>()
        let templates = try context.fetch(descriptor)
        var generatedTasks: [ExecutionTask] = []
        let targetDate = DateHelpers.startOfDay(for: date, calendar: calendar)
        let generationStartDate = generationStartDate(upTo: targetDate, calendar: calendar)
        let maxAdvanceDays = templates.map { max($0.advanceDays, 0) }.max() ?? 0
        let occurrenceEndDate = calendar.date(byAdding: .day, value: maxAdvanceDays, to: targetDate) ?? targetDate

        for template in templates {
            TemplateScheduleService.normalizeScheduleFields(for: template, referenceDate: date, calendar: calendar)
            guard template.recurrence != .onDemand else { continue }
            let templateCreatedDate = DateHelpers.startOfDay(for: template.createdAt, calendar: calendar)
            let firstOccurrenceDate = maxDate(generationStartDate, templateCreatedDate)

            for occurrenceDate in dates(from: firstOccurrenceDate, through: occurrenceEndDate, calendar: calendar) {
                guard TemplateScheduleService.occurs(template: template, on: occurrenceDate, referenceDate: date, calendar: calendar) else {
                    continue
                }

                let eligibleDate = calendar.date(
                    byAdding: .day,
                    value: -max(template.advanceDays, 0),
                    to: occurrenceDate
                ) ?? occurrenceDate
                guard eligibleDate <= targetDate else { continue }

                let task = try TemplateInstantiationService.instantiateIfNeeded(
                    template: template,
                    scheduledDate: occurrenceDate,
                    startDate: maxDate(eligibleDate, templateCreatedDate),
                    in: context
                )

                if task.source == .scheduled {
                    generatedTasks.append(task)
                }
            }
        }

        UserDefaults.standard.set(targetDate, forKey: lastGenerationCheckDateKey)
        return generatedTasks
    }

    private static func generationStartDate(upTo targetDate: Date, calendar: Calendar) -> Date {
        if let lastDate = UserDefaults.standard.object(forKey: lastGenerationCheckDateKey) as? Date {
            let nextDate = calendar.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(for: lastDate, calendar: calendar)) ?? targetDate
            return minDate(nextDate, targetDate)
        }
        return calendar.date(byAdding: .day, value: -safeBackfillDays, to: targetDate) ?? targetDate
    }

    private static func dates(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
        guard startDate <= endDate else { return [] }

        var dates: [Date] = []
        var currentDate = startDate
        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }

    private static func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}

enum NotificationSchedulingService {
    private static let identifierPrefix = "nesttask."

    private struct TemplateNotificationSnapshot {
        let id: UUID
        let title: String
        let occurrenceLabel: String
        let occurrenceDate: Date
        let notificationDate: Date
    }

    private struct ExecutionTaskNotificationSnapshot {
        let id: UUID
        let templateID: UUID?
        let title: String
        let templateTitle: String
        let notificationDate: Date
    }

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    @MainActor
    static func refreshScheduledNotifications(
        templates: [TaskTemplate],
        executionTasks: [ExecutionTask],
        requestAuthorization: Bool = true,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        if requestAuthorization {
            requestAuthorizationIfNeeded()
        }

        let scheduledTasks = executionTasks.filter { task in
            task.source == .scheduled && task.templateID != nil
        }

        let activeScheduledTasks = scheduledTasks.filter { task in
            task.status == .active && task.completedAt == nil
        }

        let taskSnapshots = activeScheduledTasks.compactMap { task -> ExecutionTaskNotificationSnapshot? in
            guard let notificationDate = notificationDate(for: task, calendar: calendar) else { return nil }
            return ExecutionTaskNotificationSnapshot(
                id: task.id,
                templateID: task.templateID,
                title: task.title,
                templateTitle: task.templateTitle ?? task.template?.title ?? task.title,
                notificationDate: notificationDate
            )
        }

        let templateSnapshots = templates.compactMap { template -> TemplateNotificationSnapshot? in
            guard
                template.recurrence != .onDemand,
                template.notificationHour != nil,
                template.notificationMinute != nil
            else {
                return nil
            }

            guard let snapshot = nextTemplateNotificationSnapshot(
                for: template,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
                return nil
            }

            let hasTaskForSameOccurrence = scheduledTasks.contains { task in
                task.templateID == template.id
                    && calendar.isDate(task.scheduledDate, inSameDayAs: snapshot.occurrenceDate)
            }

            return hasTaskForSameOccurrence ? nil : snapshot
        }

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let staleIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }

            if !staleIdentifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
            }

            for snapshot in taskSnapshots {
                scheduleExecutionTaskNotification(for: snapshot, calendar: calendar)
            }

            for snapshot in templateSnapshots {
                scheduleTemplateNotification(for: snapshot, calendar: calendar)
            }
        }
    }

    static func cancelNotifications(for template: TaskTemplate) {
        let templateID = template.id
        removePendingNotifications { identifier in
            identifier.hasPrefix(templateIdentifierPrefix(for: templateID))
        }
    }

    static func cancelNotifications(for task: ExecutionTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [executionTaskIdentifier(for: task.id)]
        )
    }

    private static func scheduleExecutionTaskNotification(for task: ExecutionTaskNotificationSnapshot, calendar: Calendar) {
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = "\(task.templateTitle)を開始する時間です"
        content.sound = .default
        content.categoryIdentifier = "nesttask.executionTask"
        content.userInfo = [
            "executionTaskID": task.id.uuidString,
            "templateID": task.templateID?.uuidString ?? ""
        ]

        addNotificationRequest(
            identifier: executionTaskIdentifier(for: task.id),
            content: content,
            date: task.notificationDate,
            calendar: calendar
        )
    }

    private static func scheduleTemplateNotification(
        for template: TemplateNotificationSnapshot,
        calendar: Calendar
    ) {
        let content = UNMutableNotificationContent()
        content.title = template.title
        content.body = "\(template.occurrenceLabel)の予定があります"
        content.sound = .default
        content.categoryIdentifier = "nesttask.template"
        content.userInfo = [
            "templateID": template.id.uuidString,
            "occurrenceDate": DateHelpers.notificationDateKey(for: template.occurrenceDate, calendar: calendar)
        ]

        addNotificationRequest(
            identifier: templateIdentifier(for: template.id, occurrenceDate: template.occurrenceDate, calendar: calendar),
            content: content,
            date: template.notificationDate,
            calendar: calendar
        )
    }

    private static func addNotificationRequest(identifier: String, content: UNNotificationContent, date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("NestTask notification scheduling failed: \(String(describing: error))")
            }
        }
    }

    private static func notificationDate(for task: ExecutionTask, calendar: Calendar) -> Date? {
        let baseDate = task.dueDate ?? task.startDate
        guard let hour = task.template?.notificationHour, let minute = task.template?.notificationMinute else {
            return nil
        }
        guard let date = notificationDate(on: baseDate, hour: hour, minute: minute, calendar: calendar) else {
            return nil
        }

        if date < Date() {
            return nil
        }
        return date
    }

    private static func notificationDate(on date: Date, hour: Int?, minute: Int?, calendar: Calendar) -> Date? {
        guard let hour, let minute else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    private static func nextTemplateNotificationSnapshot(
        for template: TaskTemplate,
        referenceDate: Date,
        searchLimitDays: Int = 370,
        calendar: Calendar
    ) -> TemplateNotificationSnapshot? {
        let startDate = DateHelpers.startOfDay(for: referenceDate, calendar: calendar)

        for offset in 0...searchLimitDays {
            guard
                let candidateDate = calendar.date(byAdding: .day, value: offset, to: startDate),
                TemplateScheduleService.occurs(template: template, on: candidateDate, referenceDate: referenceDate, calendar: calendar),
                let notificationDate = notificationDate(
                    on: candidateDate,
                    hour: template.notificationHour,
                    minute: template.notificationMinute,
                    calendar: calendar
                ),
                notificationDate >= Date()
            else {
                continue
            }

            return TemplateNotificationSnapshot(
                id: template.id,
                title: template.title,
                occurrenceLabel: notificationOccurrenceLabel(for: template),
                occurrenceDate: candidateDate,
                notificationDate: notificationDate
            )
        }

        return nil
    }

    private static func removePendingNotifications(matching predicate: @escaping (String) -> Bool) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter(predicate)
            guard !identifiers.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func notificationOccurrenceLabel(for template: TaskTemplate) -> String {
        let trimmedCadence = template.cadenceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCadence.isEmpty || trimmedCadence == "繰り返しなし" {
            return "必要な時に開始"
        }
        return trimmedCadence
    }

    private static func executionTaskIdentifier(for taskID: UUID) -> String {
        "\(identifierPrefix)execution.\(taskID.uuidString)"
    }

    private static func templateIdentifierPrefix(for templateID: UUID) -> String {
        "\(identifierPrefix)template.\(templateID.uuidString)"
    }

    private static func templateIdentifier(for templateID: UUID, occurrenceDate: Date, calendar: Calendar) -> String {
        "\(templateIdentifierPrefix(for: templateID)).\(DateHelpers.notificationDateKey(for: occurrenceDate, calendar: calendar))"
    }
}

enum TemplateInstantiationService {
    @discardableResult
    static func instantiateIfNeeded(
        template: TaskTemplate,
        scheduledDate: Date,
        startDate: Date? = nil,
        in context: ModelContext
    ) throws -> ExecutionTask {
        if let existingTask = try existingExecutionTask(
            template: template,
            scheduledDate: scheduledDate,
            in: context
        ) {
            DataIntegrityService.normalizeExecutionSteps(for: existingTask, in: context)
            return existingTask
        }

        let executionTask = instantiate(
            template: template,
            scheduledDate: scheduledDate,
            startDate: startDate ?? scheduledDate,
            source: .scheduled,
            isExpanded: true
        )
        context.insert(executionTask)
        return executionTask
    }

    @discardableResult
    static func instantiateManually(
        template: TaskTemplate,
        startDate: Date = Date(),
        in context: ModelContext
    ) -> ExecutionTask {
        let executionTask = instantiate(
            template: template,
            scheduledDate: startDate,
            startDate: startDate,
            source: .manual,
            isExpanded: true
        )
        context.insert(executionTask)
        return executionTask
    }

    static func instantiate(template: TaskTemplate, scheduledDate: Date) -> ExecutionTask {
        instantiate(
            template: template,
            scheduledDate: scheduledDate,
            startDate: scheduledDate,
            source: .scheduled,
            isExpanded: true
        )
    }

    private static func instantiate(
        template: TaskTemplate,
        scheduledDate: Date,
        startDate: Date,
        source: ExecutionSource,
        isExpanded: Bool
    ) -> ExecutionTask {
        let templateSteps = template.sortedSteps
        var stepsByTemplateStepID: [UUID: ExecutionStep] = [:]

        for templateStep in templateSteps {
            stepsByTemplateStepID[templateStep.id] = ExecutionStep(
                title: templateStep.title,
                sortIndex: templateStep.sortIndex
            )
        }

        for templateStep in templateSteps {
            guard let step = stepsByTemplateStepID[templateStep.id] else { continue }
            step.parentID = templateStep.parentID.flatMap { parentID in
                stepsByTemplateStepID[parentID]?.id
            }
        }

        return ExecutionTask(
            templateID: template.id,
            templateTitle: template.title,
            title: template.title,
            cadenceLabel: template.cadenceLabel,
            category: template.category,
            iconName: template.iconName,
            tintName: template.tintName,
            scheduledDate: DateHelpers.startOfDay(for: scheduledDate),
            startDate: DateHelpers.startOfDay(for: startDate),
            dueDate: nil,
            source: source,
            template: template,
            steps: templateSteps.compactMap { stepsByTemplateStepID[$0.id] },
            isExpanded: isExpanded
        )
    }

    private static func existingExecutionTask(
        template: TaskTemplate,
        scheduledDate: Date,
        in context: ModelContext
    ) throws -> ExecutionTask? {
        let templateID = template.id
        let dayRange = DateHelpers.dayRange(containing: scheduledDate)
        let start = dayRange.start
        let end = dayRange.end
        var descriptor = FetchDescriptor<ExecutionTask>(
            predicate: #Predicate { task in
                task.templateID == templateID
                    && task.scheduledDate >= start
                    && task.scheduledDate < end
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

enum TemplateDuplicationService {
    @discardableResult
    static func duplicate(template: TaskTemplate, in context: ModelContext) -> TaskTemplate {
        let sortedSteps = template.sortedSteps
        var stepIDMap: [UUID: UUID] = [:]
        var duplicatedSteps: [TemplateStep] = []

        for step in sortedSteps {
            let newID = UUID()
            stepIDMap[step.id] = newID
            duplicatedSteps.append(
                TemplateStep(
                    id: newID,
                    title: step.title,
                    sortIndex: step.sortIndex
                )
            )
        }

        for (index, originalStep) in sortedSteps.enumerated() {
            duplicatedSteps[index].parentID = originalStep.parentID.flatMap { stepIDMap[$0] }
        }

        let duplicatedTemplate = TaskTemplate(
            title: "\(template.title)のコピー",
            cadenceLabel: template.cadenceLabel,
            category: template.category,
            detail: template.detail,
            iconName: template.iconName,
            tintName: template.tintName,
            recurrence: template.recurrence,
            scheduledWeekday: template.scheduledWeekday,
            scheduledDay: template.scheduledDay,
            scheduledMonth: template.scheduledMonth,
            advanceDays: template.advanceDays,
            notificationHour: template.notificationHour,
            notificationMinute: template.notificationMinute,
            steps: duplicatedSteps
        )

        context.insert(duplicatedTemplate)
        return duplicatedTemplate
    }
}

enum ExecutionStepAdditionScope {
    case executionOnly
    case templateAndExecution
}

enum ExecutionTaskMutationService {
    @discardableResult
    static func addStep(
        title: String,
        parentID: UUID?,
        to task: ExecutionTask,
        scope: ExecutionStepAdditionScope,
        in context: ModelContext
    ) -> ExecutionStep? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let executionStep = ExecutionStep(
            title: trimmedTitle,
            parentID: parentID,
            sortIndex: nextExecutionSortIndex(for: task)
        )
        task.steps.append(executionStep)
        context.insert(executionStep)

        if task.status == .completed {
            task.status = .active
            task.completedAt = nil
        }
        ProgressService.refreshCompletionState(for: task)

        if scope == .templateAndExecution, let template = task.template {
            let templateStep = TemplateStep(
                title: trimmedTitle,
                parentID: templateParentID(for: parentID, task: task, template: template),
                sortIndex: nextTemplateSortIndex(for: template)
            )
            template.steps.append(templateStep)
            context.insert(templateStep)
        }

        return executionStep
    }

    private static func nextExecutionSortIndex(for task: ExecutionTask) -> Int {
        (task.steps.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func nextTemplateSortIndex(for template: TaskTemplate) -> Int {
        (template.steps.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func templateParentID(for parentID: UUID?, task: ExecutionTask, template: TaskTemplate) -> UUID? {
        guard
            let parentID,
            let parentExecutionStep = task.steps.first(where: { $0.id == parentID })
        else {
            return nil
        }

        return template.steps.first { templateStep in
            templateStep.title == parentExecutionStep.title
                && templateStep.sortIndex == parentExecutionStep.sortIndex
        }?.id
    }
}

enum DataIntegrityService {
    static func normalizeExecutionTasks(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<ExecutionTask>()
        let tasks = try context.fetch(descriptor)

        for task in tasks {
            task.templateTitle = task.templateTitle ?? task.template?.title ?? task.title
            normalizeExecutionSteps(for: task, in: context)
            ProgressService.refreshCompletionState(for: task)
        }
    }

    static func normalizeTemplateSteps(for template: TaskTemplate, in context: ModelContext) {
        let normalizedSteps = normalized(template.sortedSteps, deletingDuplicatesIn: context)

        if normalizedSteps.count != template.steps.count {
            template.steps = normalizedSteps
        }
    }

    static func normalizeExecutionSteps(for task: ExecutionTask, in context: ModelContext) {
        let normalizedSteps = normalized(task.sortedSteps, deletingDuplicatesIn: context)

        if normalizedSteps.count != task.steps.count {
            task.steps = normalizedSteps
            ProgressService.refreshCompletionState(for: task)
        }

        alignExecutionHierarchy(for: task)
    }

    private static func normalized<Step: PersistentModel & StepIdentity>(
        _ steps: [Step],
        deletingDuplicatesIn context: ModelContext
    ) -> [Step] {
        var seenKeys = Set<String>()
        var keptSteps: [Step] = []

        for step in steps {
            let parentKey = step.parentID?.uuidString ?? "root"
            let key = "\(parentKey)|\(step.sortIndex)|\(step.title)"
            if seenKeys.insert(key).inserted {
                keptSteps.append(step)
            } else {
                context.delete(step)
            }
        }

        return keptSteps
    }

    private static func alignExecutionHierarchy(for task: ExecutionTask) {
        guard let template = task.template else { return }
        let executionStepIDs = Set(task.steps.map(\.id))
        let hasInvalidParentID = task.steps.contains { step in
            guard let parentID = step.parentID else { return false }
            return !executionStepIDs.contains(parentID)
        }
        guard hasInvalidParentID else { return }

        let templateSteps = template.sortedSteps
        let executionStepsByKey = Dictionary(grouping: task.sortedSteps) { step in
            stepKey(title: step.title, sortIndex: step.sortIndex)
        }

        for templateStep in templateSteps {
            let key = stepKey(title: templateStep.title, sortIndex: templateStep.sortIndex)
            guard let executionStep = executionStepsByKey[key]?.first else { continue }

            if
                let parentTemplateID = templateStep.parentID,
                let parentTemplateStep = templateSteps.first(where: { $0.id == parentTemplateID })
            {
                let parentKey = stepKey(title: parentTemplateStep.title, sortIndex: parentTemplateStep.sortIndex)
                executionStep.parentID = executionStepsByKey[parentKey]?.first?.id
            } else {
                executionStep.parentID = nil
            }
        }
    }

    private static func stepKey(title: String, sortIndex: Int) -> String {
        "\(sortIndex)|\(title)"
    }
}

protocol StepIdentity {
    var title: String { get }
    var parentID: UUID? { get }
    var sortIndex: Int { get }
}

extension TemplateStep: StepIdentity {}
extension ExecutionStep: StepIdentity {}

enum ProgressService {
    static func completedCount(for steps: [ExecutionStep]) -> Int {
        steps.filter(\.isCompleted).count
    }

    static func totalCount(for steps: [ExecutionStep]) -> Int {
        steps.count
    }

    static func progress(for steps: [ExecutionStep]) -> Double {
        guard !steps.isEmpty else { return 0 }
        return min(Double(completedCount(for: steps)) / Double(steps.count), 1)
    }

    static func subtitle(cadenceLabel: String, category: String?, steps: [ExecutionStep]) -> String {
        let totalCount = totalCount(for: steps)
        let completedCount = completedCount(for: steps)
        let prefix = [cadenceLabel, category].compactMap { $0 }.joined(separator: "｜")

        if completedCount == 0 {
            return "\(prefix)｜\(totalCount)項目"
        }
        return "\(prefix)｜\(totalCount)項目中\(completedCount)項目完了"
    }

    static func refreshCompletionState(for task: ExecutionTask, reopensCompletedTask: Bool = false) {
        if task.status == .archived {
            return
        }

        let taskProgress = progress(for: task.steps)

        if reopensCompletedTask && taskProgress < 1 {
            task.status = .active
            task.completedAt = nil
            return
        }

        if task.status == .completed || task.completedAt != nil {
            task.status = .completed
            task.completedAt = task.completedAt ?? Date()
            return
        }

        if taskProgress >= 1 {
            task.status = .completed
            task.completedAt = task.completedAt ?? Date()
            NotificationSchedulingService.cancelNotifications(for: task)
        } else {
            task.status = .active
            task.completedAt = nil
        }
    }

    static func complete(_ task: ExecutionTask, at date: Date = Date()) {
        guard task.status != .archived else { return }
        task.status = .completed
        task.completedAt = task.completedAt ?? date
        NotificationSchedulingService.cancelNotifications(for: task)
    }
}

enum DateHelpers {
    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayRange(containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = startOfDay(for: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    static func isToday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(date)
    }

    static func japaneseMonthDayWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: date)
    }

    static func japaneseSlashMonthDayWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d（E）"
        return formatter.string(from: date)
    }

    static func notificationDateKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d%02d%02d", year, month, day)
    }

    static func backupDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }

    static func japaneseMonthDayWeekdayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）H:mm"
        return formatter.string(from: date)
    }
}
