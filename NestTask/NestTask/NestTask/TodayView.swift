import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum NestTaskStyle {
    static let background = Color(red: 0.982, green: 0.986, blue: 0.991)
    static let card = Color.white
    static let cardSubtle = Color(red: 0.965, green: 0.979, blue: 0.981)
    static let teal = Color(red: 0.08, green: 0.57, blue: 0.54)
    static let tealSoft = Color(red: 0.88, green: 0.96, blue: 0.95)
    static let blue = Color(red: 0.08, green: 0.47, blue: 0.78)
    static let amber = Color(red: 0.80, green: 0.52, blue: 0.18)
    static let green = Color(red: 0.18, green: 0.55, blue: 0.31)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let secondary = Color(red: 0.41, green: 0.43, blue: 0.48)
    static let separator = Color(red: 0.88, green: 0.90, blue: 0.93)
    static let track = Color(red: 0.91, green: 0.93, blue: 0.95)
}

enum NestTaskTint {
    static func color(for name: String) -> Color {
        switch name {
        case "blue":
            return NestTaskStyle.blue
        case "amber":
            return NestTaskStyle.amber
        case "green":
            return NestTaskStyle.green
        case "ink":
            return NestTaskStyle.ink
        default:
            return NestTaskStyle.teal
        }
    }
}

enum AppLinks {
    static let privacyPolicyURLString: String? = "https://flowerdance1123-ikki.github.io/NestTask/privacy/"
    static let supportURLString: String? = "https://flowerdance1123-ikki.github.io/NestTask/support/"

    static var privacyPolicyURL: URL? {
        guard
            let privacyPolicyURLString,
            !privacyPolicyURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return URL(string: privacyPolicyURLString)
    }

    static var supportURL: URL? {
        guard
            let supportURLString,
            !supportURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return URL(string: supportURLString)
    }
}

extension ExecutionTask {
    var tint: Color {
        NestTaskTint.color(for: tintName)
    }

    var templateNameLabel: String {
        templateTitle ?? template?.title ?? "元テンプレートなし"
    }

    var executionHierarchyNodes: [ExecutionStepNode] {
        ExecutionHierarchyBuilder.nodes(from: sortedSteps)
    }

    var todayVisibilityBadge: String? {
        guard status == .active && completedAt == nil else { return nil }

        let todayRange = DateHelpers.dayRange(containing: Date())
        if let dueDate, dueDate < todayRange.end {
            return "期限切れ"
        }
        if source == .manual {
            return "手動開始"
        }
        if scheduledDate < todayRange.start {
            return "未完の予定"
        }
        if startDate < todayRange.end && scheduledDate >= todayRange.end {
            return "事前表示"
        }
        return nil
    }
}

extension TaskTemplate {
    var tint: Color {
        NestTaskTint.color(for: tintName)
    }

    var categoryLabel: String {
        guard let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "カテゴリなし"
        }
        return category
    }

    var occurrenceLabel: String {
        let trimmedCadence = cadenceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCadence.isEmpty || trimmedCadence == "繰り返しなし" {
            return "必要な時に開始"
        }
        return trimmedCadence
    }

    var startModeLabel: String {
        occurrenceLabel == "必要な時に開始" ? "必要な時に開始" : "予定あり"
    }

    var metadataLabel: String {
        "\(occurrenceLabel)｜\(categoryLabel)"
    }

    var notificationTimeLabel: String {
        guard let notificationHour, let notificationMinute else {
            return recurrence == .onDemand ? "対象外" : "通知なし"
        }
        return String(format: "%02d:%02d", notificationHour, notificationMinute)
    }

    var stepCountText: String {
        "\(sortedSteps.count)項目"
    }

    var descriptionText: String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "メモなし" : detail
    }

    var hierarchyNodes: [TemplateStepNode] {
        TemplateHierarchyBuilder.nodes(from: sortedSteps)
    }
}

struct TemplateStepNode: Identifiable {
    let step: TemplateStep
    let depth: Int
    let children: [TemplateStepNode]

    var id: UUID {
        step.id
    }
}

struct DraftTemplateStep: Identifiable {
    let id: UUID
    var title: String
    var parentID: UUID?
    var sortIndex: Int

    init(id: UUID = UUID(), title: String, parentID: UUID? = nil, sortIndex: Int) {
        self.id = id
        self.title = title
        self.parentID = parentID
        self.sortIndex = sortIndex
    }
}

struct ExecutionStepNode: Identifiable {
    let step: ExecutionStep
    let depth: Int
    let children: [ExecutionStepNode]

    var id: UUID {
        step.id
    }
}

enum TemplateHierarchyBuilder {
    static func nodes(from steps: [TemplateStep]) -> [TemplateStepNode] {
        let groupedSteps = Dictionary(grouping: steps, by: \.parentID)

        func build(parentID: UUID?, depth: Int) -> [TemplateStepNode] {
            groupedSteps[parentID, default: []]
                .sorted { lhs, rhs in
                    if lhs.sortIndex == rhs.sortIndex {
                        return lhs.title < rhs.title
                    }
                    return lhs.sortIndex < rhs.sortIndex
                }
                .map { step in
                    TemplateStepNode(
                        step: step,
                        depth: depth,
                        children: build(parentID: step.id, depth: depth + 1)
                    )
                }
        }

        return build(parentID: nil, depth: 0)
    }
}

enum ExecutionHierarchyBuilder {
    static func nodes(from steps: [ExecutionStep]) -> [ExecutionStepNode] {
        let stepIDs = Set(steps.map(\.id))
        let groupedSteps = Dictionary(grouping: steps) { step -> UUID? in
            if let parentID = step.parentID, stepIDs.contains(parentID) {
                return parentID
            }
            return nil
        }

        func build(parentID: UUID?, depth: Int) -> [ExecutionStepNode] {
            groupedSteps[parentID, default: []]
                .sorted { lhs, rhs in
                    if lhs.sortIndex == rhs.sortIndex {
                        return lhs.title < rhs.title
                    }
                    return lhs.sortIndex < rhs.sortIndex
                }
                .map { step in
                    ExecutionStepNode(
                        step: step,
                        depth: depth,
                        children: build(parentID: step.id, depth: depth + 1)
                    )
                }
        }

        return build(parentID: nil, depth: 0)
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var didRunInitialPreparation = false
    @State private var isPreparingScheduledTasks = false

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
                .tabItem {
                    Label("今日", systemImage: "checkmark.square")
                }

            NavigationStack {
                ScheduleView()
            }
                .tabItem {
                    Label("予定", systemImage: "calendar")
                }

            NavigationStack {
                TemplatesView()
            }
            .tabItem {
                Label("テンプレート", systemImage: "square.on.square")
            }

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(NestTaskStyle.teal)
        .task {
            await runInitialPreparation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            prepareScheduledTasks(requestNotificationAuthorization: false)
        }
    }

    @MainActor
    private func runInitialPreparation() async {
        guard !didRunInitialPreparation, !isPreparingScheduledTasks else { return }
        didRunInitialPreparation = true
        isPreparingScheduledTasks = true

        try? await Task.sleep(nanoseconds: 300_000_000)
        prepareScheduledTasks(requestNotificationAuthorization: false, allowsReentry: true)
    }

    @MainActor
    private func prepareScheduledTasks(
        requestNotificationAuthorization: Bool,
        allowsReentry: Bool = false
    ) {
        if isPreparingScheduledTasks && !allowsReentry {
            return
        }
        isPreparingScheduledTasks = true
        defer {
            isPreparingScheduledTasks = false
        }

        do {
            if let template = try SampleDataSeeder.ensureSampleTemplate(in: modelContext) {
                DataIntegrityService.normalizeTemplateSteps(for: template, in: modelContext)
            }
            try TemplateScheduleService.prepareTemplateSchedules(in: modelContext)
            _ = try ScheduledTaskGenerationService.generateDueTasks(in: modelContext)
            try DataIntegrityService.normalizeExecutionTasks(in: modelContext)
            try modelContext.save()
            let templates = try modelContext.fetch(FetchDescriptor<TaskTemplate>())
            let executionTasks = try modelContext.fetch(FetchDescriptor<ExecutionTask>())
            NotificationSchedulingService.refreshScheduledNotifications(
                templates: templates,
                executionTasks: executionTasks,
                requestAuthorization: requestNotificationAuthorization
            )
        } catch {
            assertionFailure("Failed to prepare scheduled tasks: \(error)")
        }
    }
}

struct ScheduleItem: Identifiable {
    let id: String
    let templateID: UUID?
    let date: Date
    let dateLabel: String
    let title: String
    let subtitle: String
    let status: String
    let progress: Double
    let iconName: String
    let tint: Color
    let isToday: Bool
}

private enum NotificationTimePickerSupport {
    static func defaultTime(calendar: Calendar = .current) -> Date {
        date(hour: 9, minute: 0, calendar: calendar)
    }

    static func date(hour: Int?, minute: Int?, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour ?? 9
        components.minute = minute ?? 0
        return calendar.date(from: components) ?? Date()
    }

    static func hour(from date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date)
    }

    static func minute(from date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.minute, from: date)
    }
}

private enum TemplateScheduleFormSupport {
    static let occurrenceOptions = ["必要な時に開始", "毎日", "毎週", "毎月", "毎月末", "毎年"]
    static let weekdays: [(value: Int, label: String)] = [
        (1, "日曜日"),
        (2, "月曜日"),
        (3, "火曜日"),
        (4, "水曜日"),
        (5, "木曜日"),
        (6, "金曜日"),
        (7, "土曜日")
    ]

    static func cadenceLabel(
        for recurrence: TemplateRecurrence,
        weekday: Int,
        day: Int,
        month: Int
    ) -> String {
        switch recurrence {
        case .onDemand, .daily, .monthEnd:
            return recurrence.label
        case .weekly:
            return "毎週\(weekdayLabel(for: weekday))"
        case .monthly:
            return "毎月\(day)日"
        case .yearly:
            return "毎年\(month)月\(day)日"
        }
    }

    static func weekdayLabel(for weekday: Int) -> String {
        weekdays.first { $0.value == weekday }?.label ?? "曜日未設定"
    }

    static func dayCount(for month: Int) -> Int {
        switch month {
        case 2:
            return 29
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}

struct TemplateJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct TodayView: View {
    @Query(sort: \ExecutionTask.scheduledDate) private var executionTasks: [ExecutionTask]

    private var todayTasks: [ExecutionTask] {
        executionTasks.filter { task in
            shouldShowInToday(task)
                || DateHelpers.isToday(task.scheduledDate)
                || task.completedAt.map { DateHelpers.isToday($0) } == true
        }
    }

    private var tasks: [ExecutionTask] {
        executionTasks
            .filter(shouldShowInToday)
            .sorted { lhs, rhs in
                if lhs.scheduledDate == rhs.scheduledDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.scheduledDate < rhs.scheduledDate
            }
    }

    private var completedTodayCount: Int {
        todayTasks.filter { $0.status == .completed || $0.completedAt != nil }.count
    }

    private var todayProgress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(completedTodayCount) / Double(todayTasks.count)
    }

    private var todayLabel: String {
        DateHelpers.japaneseMonthDayWeekday(Date())
    }

    private func shouldShowInToday(_ task: ExecutionTask) -> Bool {
        guard task.status == .active && task.completedAt == nil else { return false }

        let dayRange = DateHelpers.dayRange(containing: Date())
        if task.source == .manual {
            return task.startDate < dayRange.end
        }
        if let dueDate = task.dueDate, dueDate < dayRange.end {
            return true
        }
        if task.scheduledDate < dayRange.end {
            return true
        }
        return task.startDate < dayRange.end
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "今日",
                subtitle: todayLabel,
                actions: [
                    HeaderAction(systemName: "magnifyingglass", tint: NestTaskStyle.ink, label: "検索"),
                    HeaderAction(systemName: "plus", tint: NestTaskStyle.teal, label: "追加")
                ]
            )

            TodayProgressCard(
                completedCount: completedTodayCount,
                totalCount: todayTasks.count,
                progress: todayProgress
            )

            VStack(spacing: 18) {
                if tasks.isEmpty {
                    ScheduleEmptyCard(message: "今日の実行タスクはありません")
                } else {
                    ForEach(tasks) { task in
                        TaskCardView(task: task, showsDetailButton: true)
                    }
                }
            }
        }
    }
}

struct ScheduleView: View {
    @Query(sort: \TaskTemplate.createdAt) private var templates: [TaskTemplate]
    @Query(sort: \ExecutionTask.scheduledDate) private var executionTasks: [ExecutionTask]
    @State private var isShowingCalendar = false

    private var calendar: Calendar {
        .current
    }

    private var today: Date {
        DateHelpers.startOfDay(for: Date(), calendar: calendar)
    }

    private var sevenDayEnd: Date {
        calendar.date(byAdding: .day, value: 7, to: today) ?? today
    }

    private var scheduledTemplates: [TaskTemplate] {
        templates.filter { $0.recurrence != .onDemand }
    }

    private var onDemandTemplates: [TaskTemplate] {
        templates.filter { $0.recurrence == .onDemand }
    }

    private var scheduleItems: [ScheduleItem] {
        let templateItems = scheduledTemplates.compactMap { item(for: $0) }
        let generatedTodayItems = todayGeneratedTasks
            .filter { !isRepresentedByTodayTemplateItem($0) }
            .map { item(for: $0) }

        return (templateItems + generatedTodayItems).sorted {
            if $0.date == $1.date {
                return $0.title < $1.title
            }
            return $0.date < $1.date
        }
    }

    private var todayItems: [ScheduleItem] {
        scheduleItems.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var upcomingWeekItems: [ScheduleItem] {
        scheduleItems.filter { item in
            item.date > today && item.date <= sevenDayEnd
        }
    }

    private var monthItems: [ScheduleItem] {
        scheduleItems.filter { item in
            item.date > sevenDayEnd && calendar.isDate(item.date, equalTo: today, toGranularity: .month)
        }
    }

    private var todayGeneratedTasks: [ExecutionTask] {
        executionTasks.filter { task in
            task.source == .scheduled && calendar.isDate(task.scheduledDate, inSameDayAs: today)
        }
    }

    private var monthScheduledCount: Int {
        scheduleItems.filter { calendar.isDate($0.date, equalTo: today, toGranularity: .month) }.count
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "予定",
                subtitle: "予定ありテンプレートと生成済みタスク",
                actions: [
                    HeaderAction(systemName: "calendar", tint: NestTaskStyle.ink, label: "カレンダー") {
                        isShowingCalendar = true
                    },
                    HeaderAction(systemName: "plus", tint: NestTaskStyle.teal, label: "追加")
                ]
            )

            HStack(spacing: 12) {
                SummaryMetricCard(
                    title: "7日間",
                    value: "\(todayItems.count + upcomingWeekItems.count)件",
                    caption: "今日生成済み \(todayGeneratedTasks.count)件",
                    systemName: "calendar.badge.clock",
                    tint: NestTaskStyle.teal
                )
                SummaryMetricCard(
                    title: "今月",
                    value: "\(monthScheduledCount)件",
                    caption: "予定あり \(scheduledTemplates.count)件 / 必要時 \(onDemandTemplates.count)件",
                    systemName: "tray.full",
                    tint: NestTaskStyle.blue
                )
            }

            scheduleSection(title: "今日の予定", items: todayItems, emptyMessage: "今日生成済みの実行タスクはありません")
            scheduleSection(title: "今後7日間", items: upcomingWeekItems, emptyMessage: "7日以内の未生成予定はありません")
            scheduleSection(title: "今月の予定", items: monthItems, emptyMessage: "今月の追加予定はありません")
        }
        .sheet(isPresented: $isShowingCalendar) {
            ScheduleCalendarView(
                templates: templates,
                executionTasks: executionTasks
            )
        }
    }

    @ViewBuilder
    private func scheduleSection(title: String, items: [ScheduleItem], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title)

            if items.isEmpty {
                ScheduleEmptyCard(message: emptyMessage)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigableScheduleCard(item: item, templates: templates)
                    }
                }
            }
        }
    }

    private func item(for template: TaskTemplate) -> ScheduleItem? {
        guard let nextDate = TemplateScheduleService.nextOccurrenceDate(for: template, from: Date(), calendar: calendar) else {
            return nil
        }

        let existingTask = generatedTask(for: template, on: nextDate)
        let status = statusLabel(for: existingTask)
        let dateLabel = scheduleDateLabel(for: nextDate)
        let subtitle = "\(template.occurrenceLabel)｜\(template.categoryLabel)｜\(template.stepCountText)"

        return ScheduleItem(
            id: "template-\(template.id.uuidString)-\(nextDate.timeIntervalSince1970)",
            templateID: template.id,
            date: nextDate,
            dateLabel: dateLabel,
            title: template.title,
            subtitle: subtitle,
            status: status,
            progress: existingTask?.progress ?? 0,
            iconName: template.iconName,
            tint: template.tint,
            isToday: calendar.isDate(nextDate, inSameDayAs: today)
        )
    }

    private func item(for task: ExecutionTask) -> ScheduleItem {
        ScheduleItem(
            id: "task-\(task.id.uuidString)",
            templateID: task.templateID ?? task.template?.id,
            date: DateHelpers.startOfDay(for: task.scheduledDate, calendar: calendar),
            dateLabel: scheduleDateLabel(for: task.scheduledDate),
            title: task.title,
            subtitle: "\(task.cadenceLabel)｜\(task.category ?? "カテゴリなし")｜\(task.totalCount)項目",
            status: statusLabel(for: task),
            progress: task.progress,
            iconName: task.iconName,
            tint: task.tint,
            isToday: calendar.isDate(task.scheduledDate, inSameDayAs: today)
        )
    }

    private func generatedTask(for template: TaskTemplate, on date: Date) -> ExecutionTask? {
        executionTasks.first { task in
            task.source == .scheduled
                && (task.templateID == template.id || task.template?.id == template.id)
                && calendar.isDate(task.scheduledDate, inSameDayAs: date)
        }
    }

    private func isRepresentedByTodayTemplateItem(_ task: ExecutionTask) -> Bool {
        guard let template = scheduledTemplates.first(where: { template in
            task.templateID == template.id || task.template?.id == template.id
        }) else {
            return false
        }

        guard let nextDate = TemplateScheduleService.nextOccurrenceDate(for: template, from: Date(), calendar: calendar) else {
            return false
        }

        return calendar.isDate(nextDate, inSameDayAs: today)
    }

    private func statusLabel(for task: ExecutionTask?) -> String {
        guard let task else { return "予定" }
        if task.status == .archived {
            return "保管済み"
        }
        if task.status == .completed || task.completedAt != nil {
            return "完了"
        }
        return "進行中"
    }

    private func scheduleDateLabel(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: today) {
            return "今日"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "明日"
        }
        return DateHelpers.japaneseSlashMonthDayWeekday(date)
    }
}

private struct ScheduleCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let templates: [TaskTemplate]
    let executionTasks: [ExecutionTask]
    @State private var selectedDate = Date()
    @State private var visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var calendar: Calendar {
        .current
    }

    private var selectedDay: Date {
        DateHelpers.startOfDay(for: selectedDate, calendar: calendar)
    }

    private var scheduledTemplates: [TaskTemplate] {
        templates
            .filter { $0.recurrence != .onDemand }
            .sorted { $0.title < $1.title }
    }

    private var selectedDateLabel: String {
        DateHelpers.japaneseMonthDayWeekday(selectedDay)
    }

    private var selectedDateItems: [ScheduleItem] {
        let templateItems = scheduledTemplates
            .filter { template in
                TemplateScheduleService.occurs(
                    template: template,
                    on: selectedDay,
                    referenceDate: selectedDay,
                    calendar: calendar
                )
            }
            .map { item(for: $0, on: selectedDay) }

        let generatedItems = generatedTasks(on: selectedDay)
            .filter { task in
                !templateItems.contains { item in
                    item.id == "template-\(task.templateID?.uuidString ?? "")-\(selectedDay.timeIntervalSince1970)"
                }
            }
            .filter { task in
                !scheduledTemplates.contains { template in
                    task.templateID == template.id || task.template?.id == template.id
                }
            }
            .map { item(for: $0) }

        return (templateItems + generatedItems).sorted {
            if $0.status == $1.status {
                return $0.title < $1.title
            }
            return $0.status < $1.status
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScheduleCalendarMonthCard(
                        visibleMonth: visibleMonth,
                        selectedDate: selectedDay,
                        markerColors: markerColors(on:),
                        onSelectDate: { date in
                            selectedDate = date
                        },
                        onMoveMonth: moveVisibleMonth
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(selectedDateLabel)

                        if selectedDateItems.isEmpty {
                            ScheduleEmptyCard(message: "この日の予定テンプレートはありません")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(selectedDateItems) { item in
                                    NavigableScheduleCard(item: item, templates: templates)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(NestTaskStyle.background)
            }
            .background(NestTaskStyle.background)
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NestTaskStyle.teal)
                }
            }
        }
    }

    private func item(for template: TaskTemplate, on date: Date) -> ScheduleItem {
        let existingTask = generatedTask(for: template, on: date)
        return ScheduleItem(
            id: "template-\(template.id.uuidString)-\(date.timeIntervalSince1970)",
            templateID: template.id,
            date: date,
            dateLabel: scheduleDateLabel(for: date),
            title: template.title,
            subtitle: "\(template.occurrenceLabel)｜\(template.categoryLabel)｜\(template.stepCountText)",
            status: statusLabel(for: existingTask),
            progress: existingTask?.progress ?? 0,
            iconName: template.iconName,
            tint: template.tint,
            isToday: calendar.isDateInToday(date)
        )
    }

    private func item(for task: ExecutionTask) -> ScheduleItem {
        ScheduleItem(
            id: "task-\(task.id.uuidString)",
            templateID: task.templateID ?? task.template?.id,
            date: DateHelpers.startOfDay(for: task.scheduledDate, calendar: calendar),
            dateLabel: scheduleDateLabel(for: task.scheduledDate),
            title: task.title,
            subtitle: "\(task.cadenceLabel)｜\(task.category ?? "カテゴリなし")｜\(task.totalCount)項目",
            status: statusLabel(for: task),
            progress: task.progress,
            iconName: task.iconName,
            tint: task.tint,
            isToday: calendar.isDateInToday(task.scheduledDate)
        )
    }

    private func generatedTask(for template: TaskTemplate, on date: Date) -> ExecutionTask? {
        executionTasks.first { task in
            task.source == .scheduled
                && (task.templateID == template.id || task.template?.id == template.id)
                && calendar.isDate(task.scheduledDate, inSameDayAs: date)
        }
    }

    private func generatedTasks(on date: Date) -> [ExecutionTask] {
        executionTasks.filter { task in
            task.source == .scheduled && calendar.isDate(task.scheduledDate, inSameDayAs: date)
        }
    }

    private func markerColors(on date: Date) -> [Color] {
        let occurringTemplates = scheduledTemplates.filter { template in
            TemplateScheduleService.occurs(
                template: template,
                on: date,
                referenceDate: date,
                calendar: calendar
            )
        }
        let representedTemplateIDs = Set(occurringTemplates.map(\.id))
        let templateColors = occurringTemplates.map(\.tint)
        let generatedColors = generatedTasks(on: date)
            .filter { task in
                guard let templateID = task.templateID else { return true }
                return !representedTemplateIDs.contains(templateID)
            }
            .map(\.tint)

        return Array((templateColors + generatedColors).prefix(3))
    }

    private func moveVisibleMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
        if !calendar.isDate(selectedDay, equalTo: visibleMonth, toGranularity: .month) {
            selectedDate = visibleMonth
        }
    }

    private func statusLabel(for task: ExecutionTask?) -> String {
        guard let task else { return "予定" }
        return statusLabel(for: task)
    }

    private func statusLabel(for task: ExecutionTask) -> String {
        if task.status == .archived {
            return "保管済み"
        }
        if task.status == .completed || task.completedAt != nil {
            return "完了"
        }
        return "進行中"
    }

    private func scheduleDateLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "今日"
        }
        return DateHelpers.japaneseSlashMonthDayWeekday(date)
    }
}

private struct ScheduleCalendarMonthCard: View {
    let visibleMonth: Date
    let selectedDate: Date
    let markerColors: (Date) -> [Color]
    let onSelectDate: (Date) -> Void
    let onMoveMonth: (Int) -> Void

    private let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var calendar: Calendar {
        .current
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: visibleMonth)
    }

    private var dayCells: [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let leadingBlankCount = max(calendar.component(.weekday, from: monthStart) - 1, 0)
        var cells: [Date?] = Array(repeating: nil, count: leadingBlankCount)

        for day in dayRange {
            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = day
            cells.append(calendar.date(from: components))
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    onMoveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .frame(width: 36, height: 36)
                        .background(NestTaskStyle.cardSubtle, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("前の月")

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)

                Spacer()

                Button {
                    onMoveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .frame(width: 36, height: 36)
                        .background(NestTaskStyle.cardSubtle, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("次の月")
            }

            HStack(spacing: 6) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(label == "日" ? NestTaskStyle.amber : NestTaskStyle.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(for: date)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
                }
            }
        }
        .padding(14)
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 13, x: 0, y: 6)
    }

    private func dayButton(for date: Date) -> some View {
        let colors = markerColors(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            onSelectDate(date)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? NestTaskStyle.teal : NestTaskStyle.ink)
                    .frame(height: 22)

                HStack(spacing: 3) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isSelected ? NestTaskStyle.tealSoft : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isToday ? NestTaskStyle.teal.opacity(0.55) : Color.clear, lineWidth: 1.2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendarAccessibilityLabel(for: date, markerCount: colors.count))
    }

    private func calendarAccessibilityLabel(for date: Date, markerCount: Int) -> String {
        let dateLabel = DateHelpers.japaneseMonthDayWeekday(date)
        guard markerCount > 0 else { return "\(dateLabel)、予定なし" }
        return "\(dateLabel)、予定あり"
    }
}

struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskTemplate.createdAt) private var templates: [TaskTemplate]
    @State private var selectedCategory = "すべて"
    @State private var isShowingCreateView = false
    @State private var isShowingExporter = false
    @State private var isShowingImporter = false
    @State private var exportDocument = TemplateJSONDocument()
    @State private var backupMessage: BackupMessage?

    private let categories = ["すべて", "仕事", "週次", "必要時"]

    private var filteredTemplates: [TaskTemplate] {
        switch selectedCategory {
        case "すべて":
            return templates
        case "必要時":
            return templates.filter { $0.startModeLabel == "必要な時に開始" }
        default:
            return templates.filter { $0.categoryLabel == selectedCategory }
        }
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "テンプレート",
                subtitle: "繰り返す作業手順を管理",
                actions: [
                    HeaderAction(systemName: "square.and.arrow.up", tint: NestTaskStyle.ink, label: "書き出し") {
                        exportTemplates()
                    },
                    HeaderAction(systemName: "square.and.arrow.down", tint: NestTaskStyle.ink, label: "読み込み") {
                        isShowingImporter = true
                    },
                    HeaderAction(systemName: "plus", tint: NestTaskStyle.teal, label: "追加") {
                        isShowingCreateView = true
                    }
                ]
            )

            CategorySelector(categories: categories, selection: $selectedCategory)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("よく使うテンプレート")

                VStack(spacing: 14) {
                    if filteredTemplates.isEmpty {
                        ScheduleEmptyCard(message: "保存済みテンプレートはありません")
                    } else {
                        ForEach(filteredTemplates) { template in
                            NavigationLink {
                                TemplateDetailView(template: template)
                            } label: {
                                TemplateCard(template: template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingCreateView) {
            TemplateCreateView()
        }
        .fileExporter(
            isPresented: $isShowingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "NestTask-Templates-\(DateHelpers.backupDateKey(Date())).json"
        ) { result in
            if case .failure(let error) = result {
                backupMessage = BackupMessage(title: "書き出しに失敗しました", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importTemplates(from: result)
        }
        .alert(item: $backupMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func exportTemplates() {
        do {
            exportDocument = TemplateJSONDocument(data: try TemplateImportExportService.exportTemplates(templates))
            isShowingExporter = true
        } catch {
            backupMessage = BackupMessage(title: "書き出しに失敗しました", message: error.localizedDescription)
        }
    }

    private func importTemplates(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let importedTemplates = try TemplateImportExportService.importTemplates(from: data, into: modelContext)
            try modelContext.save()
            refreshNotifications()
            backupMessage = BackupMessage(
                title: "読み込みました",
                message: "\(importedTemplates.count)件のテンプレートを追加しました"
            )
        } catch {
            backupMessage = BackupMessage(title: "読み込みに失敗しました", message: error.localizedDescription)
        }
    }

    private func refreshNotifications() {
        guard
            let templates = try? modelContext.fetch(FetchDescriptor<TaskTemplate>()),
            let executionTasks = try? modelContext.fetch(FetchDescriptor<ExecutionTask>())
        else {
            return
        }

        NotificationSchedulingService.refreshScheduledNotifications(
            templates: templates,
            executionTasks: executionTasks
        )
    }
}

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let template: TaskTemplate
    @State private var createdTask: ExecutionTask?
    @State private var isShowingEditView = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenContainer {
                ScreenHeader(
                    title: "テンプレート詳細",
                    subtitle: template.title,
                    actions: [
                        HeaderAction(systemName: "trash", tint: NestTaskStyle.amber, label: "削除") {
                            isShowingDeleteConfirmation = true
                        },
                        HeaderAction(systemName: "square.and.pencil", tint: NestTaskStyle.teal, label: "編集") {
                            isShowingEditView = true
                        }
                    ]
                )

                TemplateDetailSummaryCard(template: template)

                HStack(spacing: 12) {
                    SummaryMetricCard(
                        title: "項目数",
                        value: template.stepCountText,
                        caption: "テンプレート構成",
                        systemName: "checklist",
                        tint: template.tint
                    )

                    SummaryMetricCard(
                        title: "開始方法",
                        value: template.startModeLabel,
                        caption: template.occurrenceLabel,
                        systemName: "calendar.badge.clock",
                        tint: template.tint
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("親子タスク構成")

                    TemplateHierarchyCard(template: template)
                }

                Spacer()
                    .frame(height: 78)
            }

            VStack {
                Button {
                    let task = TemplateInstantiationService.instantiateManually(
                        template: template,
                        startDate: Date(),
                        in: modelContext
                    )
                    try? modelContext.save()
                    createdTask = task
                } label: {
                    Label("このテンプレートから開始", systemImage: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: NestTaskStyle.teal.opacity(0.24), radius: 16, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                LinearGradient(
                    colors: [NestTaskStyle.background.opacity(0), NestTaskStyle.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 118)
                .allowsHitTesting(false),
                alignment: .bottom
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $createdTask) { task in
            ExecutionTaskDetailView(task: task)
        }
        .navigationDestination(isPresented: $isShowingEditView) {
            TemplateEditView(template: template)
        }
        .alert("テンプレートを削除しますか？", isPresented: $isShowingDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deleteTemplate()
            }
        } message: {
            Text("このテンプレートから作成済みの実行タスクは、その時点の内容として残ります。")
        }
    }

    private func deleteTemplate() {
        NotificationSchedulingService.cancelNotifications(for: template)
        modelContext.delete(template)
        try? modelContext.save()
        refreshNotifications()
        dismiss()
    }

    private func refreshNotifications() {
        guard
            let templates = try? modelContext.fetch(FetchDescriptor<TaskTemplate>()),
            let executionTasks = try? modelContext.fetch(FetchDescriptor<ExecutionTask>())
        else {
            return
        }

        NotificationSchedulingService.refreshScheduledNotifications(
            templates: templates,
            executionTasks: executionTasks
        )
    }
}

struct TemplateCreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var category = ""
    @State private var occurrence = "必要な時に開始"
    @State private var scheduledWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var scheduledDay = Calendar.current.component(.day, from: Date())
    @State private var scheduledMonth = Calendar.current.component(.month, from: Date())
    @State private var usesNotification = false
    @State private var notificationTime = NotificationTimePickerSupport.defaultTime()
    @State private var parentDraftTitle = ""
    @State private var childDraftTitle = ""
    @State private var selectedParentID: UUID?
    @State private var draftSteps: [DraftTemplateStep] = []

    private var parentSteps: [DraftTemplateStep] {
        draftSteps
            .filter { $0.parentID == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var selectedParent: DraftTemplateStep? {
        guard let selectedParentID else { return parentSteps.first }
        return parentSteps.first { $0.id == selectedParentID }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !parentSteps.isEmpty
    }

    private var isScheduledOccurrence: Bool {
        TemplateRecurrence.from(label: occurrence) != .onDemand
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "新規テンプレート",
                subtitle: "作業の型を作成",
                actions: []
            )

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("基本情報")

                TemplateFormTextField(title: "テンプレート名", placeholder: "例：月初レポート確認", text: $title)
                TemplateFormTextField(title: "カテゴリ", placeholder: "例：仕事", text: $category)
                TemplateFormTextField(title: "メモ", placeholder: "説明や注意点", text: $detail, lineLimit: 3)

                TemplateSchedulePickerView(
                    occurrence: $occurrence,
                    scheduledWeekday: $scheduledWeekday,
                    scheduledDay: $scheduledDay,
                    scheduledMonth: $scheduledMonth
                )

                if isScheduledOccurrence {
                    TemplateNotificationSettingView(
                        isEnabled: $usesNotification,
                        notificationTime: $notificationTime
                    )
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("親タスク")

                HStack(spacing: 10) {
                    TextField("親タスク名", text: $parentDraftTitle)
                        .font(.system(size: 16, weight: .medium))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(action: addParentStep) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }

                if !parentSteps.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(parentSteps) { step in
                            DraftParentSelectionRow(
                                step: step,
                                isSelected: selectedParent?.id == step.id
                            ) {
                                selectedParentID = step.id
                            }
                        }
                    }
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("子タスク")

                if let selectedParent {
                    Text("追加先：\(selectedParent.title)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NestTaskStyle.secondary)

                    HStack(spacing: 10) {
                        TextField("子タスク名", text: $childDraftTitle)
                            .font(.system(size: 16, weight: .medium))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button(action: addChildStep) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    }
                } else {
                    Text("まず親タスクを追加してください")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NestTaskStyle.secondary)
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("親子タスク構成")

                DraftTemplatePreviewCard(steps: draftSteps)
            }

            Button(action: saveTemplate) {
                Label("テンプレートを保存", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: occurrence) { _, newValue in
            if TemplateRecurrence.from(label: newValue) == .onDemand {
                usesNotification = false
            }
        }
    }

    private func addParentStep() {
        let stepTitle = parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stepTitle.isEmpty else { return }

        let step = DraftTemplateStep(title: stepTitle, sortIndex: draftSteps.count)
        draftSteps.append(step)
        selectedParentID = step.id
        parentDraftTitle = ""
    }

    private func addChildStep() {
        let stepTitle = childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stepTitle.isEmpty, let parentID = selectedParent?.id else { return }

        draftSteps.append(
            DraftTemplateStep(
                title: stepTitle,
                parentID: parentID,
                sortIndex: draftSteps.count
            )
        )
        childDraftTitle = ""
    }

    private func saveTemplate() {
        guard canSave else { return }

        let templateSteps = draftSteps
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { draftStep in
                TemplateStep(
                    id: draftStep.id,
                    title: draftStep.title,
                    parentID: draftStep.parentID,
                    sortIndex: draftStep.sortIndex
                )
            }

        let template = TaskTemplate(
            title: trimmedTitle,
            cadenceLabel: cadenceLabelForCurrentSchedule(),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: "checklist",
            tintName: "teal",
            recurrence: TemplateRecurrence.from(label: occurrence),
            scheduledWeekday: scheduledWeekdayForOccurrence(),
            scheduledDay: scheduledDayForOccurrence(),
            scheduledMonth: scheduledMonthForOccurrence(),
            notificationHour: notificationHourForOccurrence(),
            notificationMinute: notificationMinuteForOccurrence(),
            steps: templateSteps
        )

        modelContext.insert(template)
        try? modelContext.save()
        refreshNotifications()
        dismiss()
    }

    private func cadenceLabelForCurrentSchedule() -> String {
        TemplateScheduleFormSupport.cadenceLabel(
            for: TemplateRecurrence.from(label: occurrence),
            weekday: scheduledWeekday,
            day: scheduledDay,
            month: scheduledMonth
        )
    }

    private func scheduledWeekdayForOccurrence() -> Int? {
        TemplateRecurrence.from(label: occurrence) == .weekly ? scheduledWeekday : nil
    }

    private func scheduledDayForOccurrence() -> Int? {
        let recurrence = TemplateRecurrence.from(label: occurrence)
        return recurrence == .monthly || recurrence == .yearly ? scheduledDay : nil
    }

    private func scheduledMonthForOccurrence() -> Int? {
        TemplateRecurrence.from(label: occurrence) == .yearly ? scheduledMonth : nil
    }

    private func notificationHourForOccurrence(calendar: Calendar = .current) -> Int? {
        guard isScheduledOccurrence && usesNotification else { return nil }
        return NotificationTimePickerSupport.hour(from: notificationTime, calendar: calendar)
    }

    private func notificationMinuteForOccurrence(calendar: Calendar = .current) -> Int? {
        guard isScheduledOccurrence && usesNotification else { return nil }
        return NotificationTimePickerSupport.minute(from: notificationTime, calendar: calendar)
    }

    private func refreshNotifications() {
        guard
            let templates = try? modelContext.fetch(FetchDescriptor<TaskTemplate>()),
            let executionTasks = try? modelContext.fetch(FetchDescriptor<ExecutionTask>())
        else {
            return
        }

        NotificationSchedulingService.refreshScheduledNotifications(
            templates: templates,
            executionTasks: executionTasks
        )
    }
}

struct TemplateEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: TaskTemplate

    @State private var title: String
    @State private var detail: String
    @State private var category: String
    @State private var occurrence: String
    @State private var scheduledWeekday: Int
    @State private var scheduledDay: Int
    @State private var scheduledMonth: Int
    @State private var usesNotification: Bool
    @State private var notificationTime: Date
    @State private var parentDraftTitle = ""
    @State private var childDraftTitle = ""
    @State private var selectedParentID: UUID?
    @State private var draftSteps: [DraftTemplateStep]
    @State private var pendingDeleteStep: DraftTemplateStep?

    init(template: TaskTemplate) {
        let calendar = Calendar.current
        let referenceDate = Date()
        self.template = template
        _title = State(initialValue: template.title)
        _detail = State(initialValue: template.detail)
        _category = State(initialValue: template.category ?? "")
        _occurrence = State(initialValue: template.occurrenceLabel)
        _scheduledWeekday = State(initialValue: template.scheduledWeekday ?? calendar.component(.weekday, from: referenceDate))
        _scheduledDay = State(initialValue: template.scheduledDay ?? calendar.component(.day, from: referenceDate))
        _scheduledMonth = State(initialValue: template.scheduledMonth ?? calendar.component(.month, from: referenceDate))
        _usesNotification = State(initialValue: template.notificationHour != nil && template.notificationMinute != nil)
        _notificationTime = State(initialValue: NotificationTimePickerSupport.date(
            hour: template.notificationHour,
            minute: template.notificationMinute
        ))
        _draftSteps = State(initialValue: template.sortedSteps.map { step in
            DraftTemplateStep(
                id: step.id,
                title: step.title,
                parentID: step.parentID,
                sortIndex: step.sortIndex
            )
        })
        _selectedParentID = State(initialValue: template.sortedSteps.first(where: { $0.parentID == nil })?.id)
    }

    private var parentSteps: [DraftTemplateStep] {
        draftSteps
            .filter { $0.parentID == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var selectedParent: DraftTemplateStep? {
        guard let selectedParentID else { return parentSteps.first }
        return parentSteps.first { $0.id == selectedParentID }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && parentSteps.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var isScheduledOccurrence: Bool {
        TemplateRecurrence.from(label: occurrence) != .onDemand
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "テンプレート編集",
                subtitle: template.title,
                actions: []
            )

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("基本情報")

                TemplateFormTextField(title: "テンプレート名", placeholder: "テンプレート名", text: $title)
                TemplateFormTextField(title: "カテゴリ", placeholder: "例：仕事", text: $category)
                TemplateFormTextField(title: "メモ", placeholder: "説明や注意点", text: $detail, lineLimit: 3)

                TemplateSchedulePickerView(
                    occurrence: $occurrence,
                    scheduledWeekday: $scheduledWeekday,
                    scheduledDay: $scheduledDay,
                    scheduledMonth: $scheduledMonth
                )

                if isScheduledOccurrence {
                    TemplateNotificationSettingView(
                        isEnabled: $usesNotification,
                        notificationTime: $notificationTime
                    )
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("親タスク")

                HStack(spacing: 10) {
                    TextField("親タスク名", text: $parentDraftTitle)
                        .font(.system(size: 16, weight: .medium))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(action: addParentStep) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }

                if !parentSteps.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(parentSteps) { step in
                            DraftParentSelectionRow(
                                step: step,
                                isSelected: selectedParent?.id == step.id
                            ) {
                                selectedParentID = step.id
                            }
                        }
                    }
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 16) {
                SectionTitle("子タスク")

                if let selectedParent {
                    Text("追加先：\(selectedParent.title)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NestTaskStyle.secondary)

                    HStack(spacing: 10) {
                        TextField("子タスク名", text: $childDraftTitle)
                            .font(.system(size: 16, weight: .medium))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button(action: addChildStep) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    }
                } else {
                    Text("まず親タスクを追加してください")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NestTaskStyle.secondary)
                }
            }
            .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("親子タスク構成")

                EditableDraftTemplateCard(
                    steps: draftSteps,
                    titleBinding: bindingForStepTitle,
                    onSelectParent: { selectedParentID = $0.id },
                    onDelete: { pendingDeleteStep = $0 }
                )
            }

            Button(action: saveChanges) {
                Label("変更を保存", systemImage: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("タスクを削除しますか？", isPresented: deleteAlertBinding) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let pendingDeleteStep {
                    deleteStep(pendingDeleteStep)
                }
            }
        } message: {
            Text(pendingDeleteStep?.parentID == nil ? "この親タスクと子タスクを削除します。" : "この子タスクを削除します。")
        }
        .onChange(of: occurrence) { _, newValue in
            if TemplateRecurrence.from(label: newValue) == .onDemand {
                usesNotification = false
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding {
            pendingDeleteStep != nil
        } set: { isPresented in
            if !isPresented {
                pendingDeleteStep = nil
            }
        }
    }

    private func bindingForStepTitle(_ step: DraftTemplateStep) -> Binding<String> {
        Binding {
            draftSteps.first(where: { $0.id == step.id })?.title ?? ""
        } set: { newValue in
            guard let index = draftSteps.firstIndex(where: { $0.id == step.id }) else { return }
            draftSteps[index].title = newValue
        }
    }

    private func addParentStep() {
        let stepTitle = parentDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stepTitle.isEmpty else { return }

        let step = DraftTemplateStep(title: stepTitle, sortIndex: draftSteps.count)
        draftSteps.append(step)
        selectedParentID = step.id
        parentDraftTitle = ""
    }

    private func addChildStep() {
        let stepTitle = childDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stepTitle.isEmpty, let parentID = selectedParent?.id else { return }

        draftSteps.append(
            DraftTemplateStep(
                title: stepTitle,
                parentID: parentID,
                sortIndex: draftSteps.count
            )
        )
        childDraftTitle = ""
    }

    private func deleteStep(_ step: DraftTemplateStep) {
        if step.parentID == nil {
            draftSteps.removeAll { $0.id == step.id || $0.parentID == step.id }
            if selectedParentID == step.id {
                selectedParentID = parentSteps.first?.id
            }
        } else {
            draftSteps.removeAll { $0.id == step.id }
        }
        normalizeDraftSortIndexes()
    }

    private func saveChanges() {
        guard canSave else { return }

        NotificationSchedulingService.cancelNotifications(for: template)

        let sanitizedSteps = sanitizedDraftSteps()
        let existingStepsByID = Dictionary(uniqueKeysWithValues: template.steps.map { ($0.id, $0) })
        var savedSteps: [TemplateStep] = []

        for (index, draftStep) in sanitizedSteps.enumerated() {
            let step = existingStepsByID[draftStep.id] ?? TemplateStep(id: draftStep.id, title: draftStep.title, sortIndex: index)
            step.title = draftStep.title.trimmingCharacters(in: .whitespacesAndNewlines)
            step.parentID = draftStep.parentID
            step.sortIndex = index
            savedSteps.append(step)
        }

        let savedStepIDs = Set(savedSteps.map(\.id))
        for step in template.steps where !savedStepIDs.contains(step.id) {
            modelContext.delete(step)
        }

        template.title = trimmedTitle
        template.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        template.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines)
        template.recurrence = TemplateRecurrence.from(label: occurrence)
        applyScheduleSelection()
        applyNotificationTime()
        template.steps = savedSteps

        try? modelContext.save()
        refreshNotifications()
        dismiss()
    }

    private func sanitizedDraftSteps() -> [DraftTemplateStep] {
        let nonEmptySteps = draftSteps
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.sortIndex < $1.sortIndex }
        let validStepIDs = Set(nonEmptySteps.map(\.id))

        return nonEmptySteps
            .filter { step in
                step.parentID == nil || validStepIDs.contains(step.parentID!)
            }
            .enumerated()
            .map { index, step in
                DraftTemplateStep(
                    id: step.id,
                    title: step.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentID: step.parentID,
                    sortIndex: index
                )
            }
    }

    private func normalizeDraftSortIndexes() {
        draftSteps = draftSteps
            .sorted { $0.sortIndex < $1.sortIndex }
            .enumerated()
            .map { index, step in
                DraftTemplateStep(
                    id: step.id,
                    title: step.title,
                    parentID: step.parentID,
                    sortIndex: index
                )
            }
    }

    private func applyScheduleSelection() {
        template.cadenceLabel = TemplateScheduleFormSupport.cadenceLabel(
            for: template.recurrence,
            weekday: scheduledWeekday,
            day: scheduledDay,
            month: scheduledMonth
        )

        switch template.recurrence {
        case .onDemand, .daily, .monthEnd:
            template.scheduledWeekday = nil
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .weekly:
            template.scheduledWeekday = scheduledWeekday
            template.scheduledDay = nil
            template.scheduledMonth = nil
        case .monthly:
            template.scheduledWeekday = nil
            template.scheduledDay = scheduledDay
            template.scheduledMonth = nil
        case .yearly:
            template.scheduledWeekday = nil
            template.scheduledDay = scheduledDay
            template.scheduledMonth = scheduledMonth
        }
    }

    private func applyNotificationTime(calendar: Calendar = .current) {
        guard isScheduledOccurrence && usesNotification else {
            template.notificationHour = nil
            template.notificationMinute = nil
            return
        }

        template.notificationHour = NotificationTimePickerSupport.hour(from: notificationTime, calendar: calendar)
        template.notificationMinute = NotificationTimePickerSupport.minute(from: notificationTime, calendar: calendar)
    }

    private func refreshNotifications() {
        guard
            let templates = try? modelContext.fetch(FetchDescriptor<TaskTemplate>()),
            let executionTasks = try? modelContext.fetch(FetchDescriptor<ExecutionTask>())
        else {
            return
        }

        NotificationSchedulingService.refreshScheduledNotifications(
            templates: templates,
            executionTasks: executionTasks
        )
    }
}

private struct TemplateFormTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var lineLimit: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary)

            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
                .lineLimit(lineLimit, reservesSpace: lineLimit > 1)
                .padding(.horizontal, 14)
                .padding(.vertical, lineLimit > 1 ? 12 : 0)
                .frame(minHeight: lineLimit > 1 ? 84 : 48)
                .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct TemplateSchedulePickerView: View {
    @Binding var occurrence: String
    @Binding var scheduledWeekday: Int
    @Binding var scheduledDay: Int
    @Binding var scheduledMonth: Int

    private var recurrence: TemplateRecurrence {
        TemplateRecurrence.from(label: occurrence)
    }

    private var yearlyDayRange: ClosedRange<Int> {
        1...TemplateScheduleFormSupport.dayCount(for: scheduledMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("発生方法")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary)

            Menu {
                ForEach(TemplateScheduleFormSupport.occurrenceOptions, id: \.self) { option in
                    Button(option) {
                        occurrence = option
                        normalizeSelectedDay()
                    }
                }
            } label: {
                SelectionFieldLabel(text: occurrence)
            }
            .buttonStyle(.plain)

            scheduleDetailPicker
        }
        .onChange(of: scheduledMonth) { _, _ in
            normalizeSelectedDay()
        }
        .onAppear {
            normalizeSelectedDay()
        }
    }

    @ViewBuilder
    private var scheduleDetailPicker: some View {
        switch recurrence {
        case .onDemand, .daily, .monthEnd:
            EmptyView()
        case .weekly:
            labeledMenu(title: "曜日", value: TemplateScheduleFormSupport.weekdayLabel(for: scheduledWeekday)) {
                ForEach(TemplateScheduleFormSupport.weekdays, id: \.value) { weekday in
                    Button(weekday.label) {
                        scheduledWeekday = weekday.value
                    }
                }
            }
        case .monthly:
            labeledMenu(title: "発生日", value: "\(scheduledDay)日") {
                ForEach(1...31, id: \.self) { day in
                    Button("\(day)日") {
                        scheduledDay = day
                    }
                }
            }
        case .yearly:
            HStack(spacing: 10) {
                labeledMenu(title: "月", value: "\(scheduledMonth)月") {
                    ForEach(1...12, id: \.self) { month in
                        Button("\(month)月") {
                            scheduledMonth = month
                        }
                    }
                }

                labeledMenu(title: "日", value: "\(scheduledDay)日") {
                    ForEach(yearlyDayRange, id: \.self) { day in
                        Button("\(day)日") {
                            scheduledDay = day
                        }
                    }
                }
            }
        }
    }

    private func labeledMenu<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary.opacity(0.86))

            Menu {
                content()
            } label: {
                SelectionFieldLabel(text: value)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func normalizeSelectedDay() {
        guard recurrence == .yearly else { return }
        scheduledDay = min(scheduledDay, TemplateScheduleFormSupport.dayCount(for: scheduledMonth))
    }
}

private struct SelectionFieldLabel: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(NestTaskStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TemplateNotificationSettingView: View {
    @Binding var isEnabled: Bool
    @Binding var notificationTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isEnabled) {
                Label("通知を使う", systemImage: "bell.badge")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
            }
            .tint(NestTaskStyle.teal)

            if isEnabled {
                DatePicker(
                    "通知時刻",
                    selection: $notificationTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary)
                .datePickerStyle(.compact)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DraftParentSelectionRow: View {
    let step: DraftTemplateStep
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? NestTaskStyle.teal : NestTaskStyle.secondary)
                    .frame(width: 28, height: 28)

                Text(step.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                isSelected ? NestTaskStyle.tealSoft : NestTaskStyle.cardSubtle,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? NestTaskStyle.teal.opacity(0.55) : NestTaskStyle.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DraftTemplatePreviewCard: View {
    let steps: [DraftTemplateStep]

    private var parentSteps: [DraftTemplateStep] {
        steps
            .filter { $0.parentID == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private func children(for parent: DraftTemplateStep) -> [DraftTemplateStep] {
        steps
            .filter { $0.parentID == parent.id }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            if parentSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("まだタスクがありません")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)

                    Text("親タスクを追加すると構成が表示されます")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NestTaskStyle.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            } else {
                ForEach(Array(parentSteps.enumerated()), id: \.element.id) { index, parent in
                    DraftTemplatePreviewParentRow(parent: parent, children: children(for: parent))

                    if index != parentSteps.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                            .overlay(NestTaskStyle.separator.opacity(0.85))
                    }
                }
            }
        }
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 13, x: 0, y: 6)
    }
}

private struct DraftTemplatePreviewParentRow: View {
    let parent: DraftTemplateStep
    let children: [DraftTemplateStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DraftTemplatePreviewStepRow(title: parent.title, depth: 0)

            ForEach(children) { child in
                DraftTemplatePreviewStepRow(title: child.title, depth: 1)
            }
        }
    }
}

private struct DraftTemplatePreviewStepRow: View {
    let title: String
    let depth: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(depth == 0 ? NestTaskStyle.tealSoft : NestTaskStyle.cardSubtle)
                    .frame(width: 26, height: 26)

                Circle()
                    .stroke(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.separator, lineWidth: 1.5)
                    .frame(width: 26, height: 26)

                Circle()
                    .fill(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.secondary.opacity(0.55))
                    .frame(width: 6, height: 6)
            }

            Text(title)
                .font(.system(size: 16, weight: depth == 0 ? .bold : .medium))
                .foregroundStyle(NestTaskStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 18 + CGFloat(depth * 28))
        .padding(.trailing, 18)
        .frame(minHeight: 52)
    }
}

private struct EditableDraftTemplateCard: View {
    let steps: [DraftTemplateStep]
    let titleBinding: (DraftTemplateStep) -> Binding<String>
    let onSelectParent: (DraftTemplateStep) -> Void
    let onDelete: (DraftTemplateStep) -> Void

    private var parentSteps: [DraftTemplateStep] {
        steps
            .filter { $0.parentID == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private func children(for parent: DraftTemplateStep) -> [DraftTemplateStep] {
        steps
            .filter { $0.parentID == parent.id }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            if parentSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("タスクがありません")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)

                    Text("親タスクを追加してください")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NestTaskStyle.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            } else {
                ForEach(Array(parentSteps.enumerated()), id: \.element.id) { index, parent in
                    VStack(spacing: 0) {
                        EditableDraftStepRow(
                            title: titleBinding(parent),
                            depth: 0,
                            placeholder: "親タスク名",
                            onFocusParent: { onSelectParent(parent) },
                            onDelete: { onDelete(parent) }
                        )

                        ForEach(children(for: parent)) { child in
                            EditableDraftStepRow(
                                title: titleBinding(child),
                                depth: 1,
                                placeholder: "子タスク名",
                                onFocusParent: { onSelectParent(parent) },
                                onDelete: { onDelete(child) }
                            )
                        }
                    }

                    if index != parentSteps.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                            .overlay(NestTaskStyle.separator.opacity(0.85))
                    }
                }
            }
        }
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 13, x: 0, y: 6)
    }
}

private struct EditableDraftStepRow: View {
    @Binding var title: String
    let depth: Int
    let placeholder: String
    let onFocusParent: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(depth == 0 ? NestTaskStyle.tealSoft : NestTaskStyle.cardSubtle)
                    .frame(width: 26, height: 26)

                Circle()
                    .stroke(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.separator, lineWidth: 1.5)
                    .frame(width: 26, height: 26)

                Circle()
                    .fill(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.secondary.opacity(0.55))
                    .frame(width: 6, height: 6)
            }
            .accessibilityHidden(true)

            TextField(placeholder, text: $title)
                .font(.system(size: 16, weight: depth == 0 ? .bold : .medium))
                .foregroundStyle(NestTaskStyle.ink)
                .textFieldStyle(.plain)
                .onTapGesture(perform: onFocusParent)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NestTaskStyle.amber)
                    .frame(width: 36, height: 36)
                    .background(NestTaskStyle.amber.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("削除")
        }
        .padding(.leading, 18 + CGFloat(depth * 28))
        .padding(.trailing, 12)
        .frame(minHeight: 54)
    }
}

struct ExecutionTaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: ExecutionTask
    @State private var newStepTitle = ""
    @State private var selectedParentID: UUID?
    @State private var isShowingStepAdditionChoice = false

    private var startedAtLabel: String {
        DateHelpers.japaneseMonthDayWeekday(task.startDate)
    }

    private var dueDateLabel: String {
        guard let dueDate = task.dueDate else { return "なし" }
        return DateHelpers.japaneseMonthDayWeekday(dueDate)
    }

    private var progressPercentage: String {
        "\(Int((task.progress * 100).rounded()))%"
    }

    private var completionCountLabel: String {
        "\(task.completedCount) / \(task.totalCount)"
    }

    private var canReflectToTemplate: Bool {
        task.template != nil
    }

    private var sanitizedSelectedParentID: UUID? {
        guard
            let selectedParentID,
            task.steps.contains(where: { $0.id == selectedParentID })
        else {
            return nil
        }
        return selectedParentID
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "実行タスク",
                subtitle: task.title,
                actions: []
            )

            ExecutionTaskSummaryCard(
                task: task,
                startedAtLabel: startedAtLabel,
                dueDateLabel: dueDateLabel
            )

            HStack(spacing: 12) {
                SummaryMetricCard(
                    title: "進捗率",
                    value: progressPercentage,
                    caption: "\(task.totalCount)項目中\(task.completedCount)項目完了",
                    systemName: "chart.bar",
                    tint: task.tint
                )

                SummaryMetricCard(
                    title: "完了数",
                    value: completionCountLabel,
                    caption: "完了数 / 全体数",
                    systemName: "checkmark.circle",
                    tint: task.tint
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("親子タスクチェックリスト")

                ExecutionChecklistCard(task: task)
            }

            if task.status == .active {
                ExecutionStepAddCard(
                    task: task,
                    title: $newStepTitle,
                    selectedParentID: $selectedParentID,
                    canReflectToTemplate: canReflectToTemplate
                ) {
                    if canReflectToTemplate {
                        isShowingStepAdditionChoice = true
                    } else {
                        addNewStep(scope: .executionOnly)
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    ProgressService.complete(task)
                }
                try? modelContext.save()
            } label: {
                Label(task.status == .completed ? "完了済み" : "完了にする", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(task.status == .completed ? task.tint : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        task.status == .completed ? task.tint.opacity(0.10) : task.tint,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(task.status == .completed)
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "この項目をテンプレートにも追加しますか？",
            isPresented: $isShowingStepAdditionChoice,
            titleVisibility: .visible
        ) {
            Button("テンプレートにも追加") {
                addNewStep(scope: .templateAndExecution)
            }

            Button("今回だけ追加") {
                addNewStep(scope: .executionOnly)
            }

            Button("キャンセル", role: .cancel) {}
        }
    }

    private func addNewStep(scope: ExecutionStepAdditionScope) {
        guard
            ExecutionTaskMutationService.addStep(
                title: newStepTitle,
                parentID: sanitizedSelectedParentID,
                to: task,
                scope: scope,
                in: modelContext
            ) != nil
        else {
            return
        }

        newStepTitle = ""
        selectedParentID = nil
        try? modelContext.save()
    }
}

private struct ExecutionTaskSummaryCard: View {
    let task: ExecutionTask
    let startedAtLabel: String
    let dueDateLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                IconTile(systemName: task.iconName, tint: task.tint)

                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 8) {
                        StatusBadge(text: task.source == .manual ? "手動開始" : "予定から生成", tint: task.tint)
                        StatusBadge(text: task.category ?? "カテゴリなし", tint: NestTaskStyle.ink)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("元テンプレート")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NestTaskStyle.secondary)

                Text(task.templateNameLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            HStack(spacing: 10) {
                DetailInfoPill(title: "開始日", value: startedAtLabel, tint: task.tint)
                DetailInfoPill(title: "期限", value: dueDateLabel, tint: task.tint)
            }
        }
        .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)
    }
}

private struct ExecutionStepAddCard: View {
    let task: ExecutionTask
    @Binding var title: String
    @Binding var selectedParentID: UUID?
    let canReflectToTemplate: Bool
    let onAdd: () -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedParentLabel: String {
        guard
            let selectedParentID,
            let selectedStep = task.sortedSteps.first(where: { $0.id == selectedParentID })
        else {
            return "親タスクとして追加"
        }
        return selectedStep.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(task.tint)
                    .frame(width: 30, height: 30)
                    .background(task.tint.opacity(0.10), in: Circle())

                SectionTitle("項目を追加")
            }

            TextField("追加する項目名", text: $title)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("追加先")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NestTaskStyle.secondary)

                Menu {
                    Button("親タスクとして追加") {
                        selectedParentID = nil
                    }

                    if !task.sortedSteps.isEmpty {
                        Divider()
                    }

                    ForEach(task.sortedSteps) { step in
                        Button(step.title) {
                            selectedParentID = step.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedParentLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(NestTaskStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(NestTaskStyle.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onAdd) {
                Label(canReflectToTemplate ? "追加方法を選ぶ" : "今回だけ追加", systemImage: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(task.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(trimmedTitle.isEmpty)
            .opacity(trimmedTitle.isEmpty ? 0.45 : 1)
        }
        .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)
    }
}

private struct TemplateDetailSummaryCard: View {
    let template: TaskTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                IconTile(systemName: template.iconName, tint: template.tint)

                VStack(alignment: .leading, spacing: 7) {
                    Text(template.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 8) {
                        StatusBadge(text: template.startModeLabel, tint: template.tint)
                        StatusBadge(text: template.categoryLabel, tint: NestTaskStyle.ink)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("メモ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NestTaskStyle.secondary)

                Text(template.descriptionText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NestTaskStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                DetailInfoPill(title: "カテゴリ", value: template.categoryLabel, tint: template.tint)
                DetailInfoPill(title: "発生方法", value: template.occurrenceLabel, tint: template.tint)
                DetailInfoPill(title: "通知", value: template.notificationTimeLabel, tint: template.tint)
            }
        }
        .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)
    }
}

private struct DetailInfoPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NestTaskStyle.secondary)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TemplateHierarchyCard: View {
    let template: TaskTemplate

    var body: some View {
        VStack(spacing: 0) {
            TemplateRootRow(template: template)

            Divider()
                .overlay(NestTaskStyle.separator)

            VStack(spacing: 0) {
                ForEach(Array(template.hierarchyNodes.enumerated()), id: \.element.id) { index, node in
                    TemplateStepNodeView(node: node, isLastRoot: index == template.hierarchyNodes.count - 1)
                }
            }
            .overlay(alignment: .leading) {
                DashedGuide()
                    .stroke(NestTaskStyle.separator, style: StrokeStyle(lineWidth: 1.2, dash: [6, 7], dashPhase: 2))
                    .frame(width: 1)
                    .padding(.leading, 47)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 13, x: 0, y: 6)
    }
}

private struct TemplateRootRow: View {
    let template: TaskTemplate

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: template.iconName, tint: template.tint, size: 48, iconSize: 20)

            VStack(alignment: .leading, spacing: 5) {
                Text(template.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("親タスク｜\(template.stepCountText)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NestTaskStyle.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct TemplateStepNodeView: View {
    let node: TemplateStepNode
    let isLastRoot: Bool

    var body: some View {
        VStack(spacing: 0) {
            TemplateStepRow(node: node)

            ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                TemplateStepNodeView(node: child, isLastRoot: isLastRoot && index == node.children.count - 1)
            }

            if !isLastRoot {
                Divider()
                    .padding(.leading, 118)
                    .overlay(NestTaskStyle.separator.opacity(0.85))
            }
        }
    }
}

private struct TemplateStepRow: View {
    let node: TemplateStepNode

    private var leadingPadding: CGFloat {
        78 + CGFloat(node.depth * 22)
    }

    var body: some View {
        HStack(spacing: 14) {
            TemplateStepMarker(depth: node.depth)

            Text(node.step.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(NestTaskStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, 18)
        .frame(minHeight: 56)
    }
}

private struct TemplateStepMarker: View {
    let depth: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(depth == 0 ? NestTaskStyle.tealSoft : NestTaskStyle.cardSubtle)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.separator, lineWidth: 1.6)
                .frame(width: 28, height: 28)

            Circle()
                .fill(depth == 0 ? NestTaskStyle.teal : NestTaskStyle.secondary.opacity(0.55))
                .frame(width: 7, height: 7)
        }
        .accessibilityHidden(true)
    }
}

struct HistoryView: View {
    @Query(sort: \ExecutionTask.createdAt, order: .reverse) private var executionTasks: [ExecutionTask]
    @State private var isShowingPrivacyInfo = false

    private var completedTasks: [ExecutionTask] {
        executionTasks
            .filter { $0.status == .completed || $0.completedAt != nil }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? lhs.createdAt) > (rhs.completedAt ?? rhs.createdAt)
            }
    }

    private var incompleteCompletedCount: Int {
        completedTasks.filter { $0.progress < 1 }.count
    }

    var body: some View {
        ScreenContainer {
            ScreenHeader(
                title: "履歴",
                subtitle: "完了した実行タスク",
                actions: [
                    HeaderAction(systemName: "info.circle", tint: NestTaskStyle.ink, label: "アプリ情報") {
                        isShowingPrivacyInfo = true
                    }
                ]
            )

            VStack(spacing: 12) {
                HistorySummaryCard(
                    completedCount: completedTasks.count,
                    incompleteCompletedCount: incompleteCompletedCount
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("最近の完了")

                VStack(spacing: 12) {
                    if completedTasks.isEmpty {
                        EmptyHistoryCard()
                    } else {
                        ForEach(completedTasks) { task in
                            HistoryCard(task: task)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingPrivacyInfo) {
            AppInfoView()
        }
    }
}

private struct AppInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var privacyPolicyURL: URL? {
        AppLinks.privacyPolicyURL
    }

    private var supportURL: URL? {
        AppLinks.supportURL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NestTask")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(NestTaskStyle.ink)

                        Text("作業テンプレートを実行タスクへ変換して進める、ローカル保存のタスク管理アプリです。")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NestTaskStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("プライバシー")

                        Text("テンプレート、実行タスク、履歴、通知設定は端末内に保存されます。現時点では外部サーバーへの同期や送信は行いません。JSONバックアップはユーザーが選択した保存先に書き出されます。")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NestTaskStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            guard let privacyPolicyURL else { return }
                            openURL(privacyPolicyURL)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "safari")
                                    .font(.system(size: 17, weight: .bold))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("プライバシーポリシーを開く")
                                        .font(.system(size: 15, weight: .bold))

                                    Text(privacyPolicyURL?.absoluteString ?? "URL未設定")
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(privacyPolicyURL == nil ? NestTaskStyle.secondary : NestTaskStyle.teal)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(privacyPolicyURL == nil)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("サポート")

                        Button {
                            guard let supportURL else { return }
                            openURL(supportURL)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 17, weight: .bold))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("サポート")
                                        .font(.system(size: 15, weight: .bold))

                                    Text("お問い合わせ・不具合報告")
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(supportURL == nil ? NestTaskStyle.secondary : NestTaskStyle.teal)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .background(NestTaskStyle.cardSubtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(supportURL == nil)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("通知")

                        Text("ローカル通知は予定を思い出すためだけに使います。実行タスクの生成は、アプリ起動時と復帰時にも確認します。")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NestTaskStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
            }
            .background(NestTaskStyle.background)
            .navigationTitle("アプリ情報")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ScreenContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            NestTaskStyle.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
    }
}

struct HeaderAction: Identifiable {
    let id = UUID()
    let systemName: String
    let tint: Color
    let label: String
    var action: (() -> Void)? = nil
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    let actions: [HeaderAction]

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(NestTaskStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                ForEach(actions) { action in
                    HeaderIconButton(action: action)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct HeaderIconButton: View {
    let action: HeaderAction

    var body: some View {
        Button {
            action.action?()
        } label: {
            Image(systemName: action.systemName)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(action.tint)
                .frame(width: 52, height: 52)
                .background(.white, in: Circle())
                .overlay(
                    Circle()
                        .stroke(NestTaskStyle.separator.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
    }
}

struct TodayProgressCard: View {
    let completedCount: Int
    let totalCount: Int
    let progress: Double

    private var percentage: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(NestTaskStyle.teal)
                    .frame(width: 28, height: 28)
                    .background(Circle().stroke(NestTaskStyle.teal, lineWidth: 1.7))

                Text("今日の進捗")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NestTaskStyle.secondary)

                Spacer()
            }

            HStack(alignment: .lastTextBaseline) {
                Text("\(totalCount)件中 \(completedCount)件完了")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 14)

                Text("\(percentage)%")
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(NestTaskStyle.teal)
            }

            ProgressBar(progress: progress, height: 8)
        }
        .taskCard(cornerRadius: 20, padding: 22, shadowOpacity: 0.07)
    }
}

struct SummaryMetricCard: View {
    let title: String
    let value: String
    let caption: String
    let systemName: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NestTaskStyle.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(NestTaskStyle.ink)

            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NestTaskStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.045)
    }
}

struct TaskCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: ExecutionTask
    let showsDetailButton: Bool

    init(task: ExecutionTask, showsDetailButton: Bool = false) {
        self.task = task
        self.showsDetailButton = showsDetailButton
    }

    private var percentage: Int {
        Int((task.progress * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            TaskCardHeader(
                task: task,
                percentage: percentage,
                showsDetailButton: showsDetailButton,
                onToggle: toggleExpansion
            )

            if task.isExpanded {
                ChildTaskList(task: task)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.055), radius: 13, x: 0, y: 6)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: task.isExpanded)
        .accessibilityElement(children: .contain)
    }

    private func toggleExpansion() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            task.isExpanded.toggle()
        }
        try? modelContext.save()
    }
}

private struct TaskCardHeader: View {
    let task: ExecutionTask
    let percentage: Int
    let showsDetailButton: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                IconTile(systemName: task.iconName, tint: task.tint)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(task.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NestTaskStyle.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if let badge = task.todayVisibilityBadge {
                        StatusBadge(text: badge, tint: badge == "期限切れ" ? NestTaskStyle.amber : task.tint)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 14) {
                    Text("\(percentage)%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(task.progress == 0 ? NestTaskStyle.secondary.opacity(0.72) : task.tint)
                        .frame(minWidth: 44, alignment: .trailing)

                    if showsDetailButton {
                        NavigationLink {
                            ExecutionTaskDetailView(task: task)
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(task.tint)
                                .frame(width: 32, height: 32)
                                .background(task.tint.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("詳細")
                    }

                    Button(action: onToggle) {
                        Image(systemName: task.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(NestTaskStyle.ink)
                            .frame(width: 32, height: 32)
                            .background(NestTaskStyle.cardSubtle, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isExpanded ? "折りたたむ" : "展開")
                }
            }

            ProgressBar(progress: task.progress, height: 6)
                .padding(.leading, 68)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct ChildTaskList: View {
    @Bindable var task: ExecutionTask
    @State private var expandedStepIDs: Set<UUID> = []

    private var rootNodes: [ExecutionStepNode] {
        task.executionHierarchyNodes
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(NestTaskStyle.separator)

            VStack(spacing: 0) {
                ForEach(Array(rootNodes.enumerated()), id: \.element.id) { index, node in
                    ChildTaskNodeRow(
                        node: node,
                        isLastVisibleRow: index == rootNodes.count - 1,
                        expandedStepIDs: $expandedStepIDs
                    )
                }
            }
        }
        .onAppear {
            if expandedStepIDs.isEmpty {
                expandedStepIDs = Set(rootNodes.map(\.id))
            }
        }
    }
}

private struct ChildTaskNodeRow: View {
    let node: ExecutionStepNode
    let isLastVisibleRow: Bool
    @Binding var expandedStepIDs: Set<UUID>

    private var isExpanded: Bool {
        expandedStepIDs.contains(node.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            ChildTaskRow(
                step: node.step,
                depth: node.depth,
                hasChildren: !node.children.isEmpty,
                isExpanded: isExpanded,
                onToggleExpansion: toggleExpansion
            )

            if isExpanded {
                ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                    ChildTaskNodeRow(
                        node: child,
                        isLastVisibleRow: isLastVisibleRow && index == node.children.count - 1,
                        expandedStepIDs: $expandedStepIDs
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !isLastVisibleRow {
                Divider()
                    .padding(.leading, dividerLeadingPadding)
                    .overlay(NestTaskStyle.separator.opacity(0.85))
            }
        }
    }

    private var dividerLeadingPadding: CGFloat {
        118 + CGFloat(node.depth * 24)
    }

    private func toggleExpansion() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            if isExpanded {
                expandedStepIDs.remove(node.id)
            } else {
                expandedStepIDs.insert(node.id)
            }
        }
    }
}

private struct ChildTaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var step: ExecutionStep
    let depth: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let onToggleExpansion: () -> Void

    private var leadingPadding: CGFloat {
        18 + CGFloat(depth * 24)
    }

    private var rowBackground: Color {
        depth == 0 ? NestTaskStyle.card : NestTaskStyle.cardSubtle.opacity(0.54)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion()
            } label: {
                HStack(spacing: 12) {
                    CircleCheckmark(isCompleted: step.isCompleted)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(.system(size: 17, weight: depth == 0 ? .semibold : .medium))
                            .foregroundStyle(step.isCompleted ? NestTaskStyle.secondary.opacity(0.72) : NestTaskStyle.ink)
                            .strikethrough(step.isCompleted, color: NestTaskStyle.secondary.opacity(0.72))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)

                        Text(depth == 0 ? "親タスク" : "子タスク")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NestTaskStyle.secondary.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step.title)
            .accessibilityValue(step.isCompleted ? "完了" : "未完了")

            if hasChildren {
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .frame(width: 30, height: 30)
                        .background(NestTaskStyle.card, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "子タスクを閉じる" : "子タスクを開く")
            }
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
        .frame(minHeight: 58)
        .background(rowBackground)
        .contentShape(Rectangle())
    }

    private func toggleCompletion() {
        withAnimation(.easeInOut(duration: 0.18)) {
            step.isCompleted.toggle()
            step.completedAt = step.isCompleted ? .now : nil
            if let task = step.executionTask {
                ProgressService.refreshCompletionState(for: task)
            }
        }
        try? modelContext.save()
    }
}

private struct ExecutionChecklistCard: View {
    @Bindable var task: ExecutionTask

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(task.executionHierarchyNodes.enumerated()), id: \.element.id) { index, node in
                ExecutionStepNodeView(
                    node: node,
                    isLastRoot: index == task.executionHierarchyNodes.count - 1
                )
            }
        }
        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.045), radius: 13, x: 0, y: 6)
    }
}

private struct ExecutionStepNodeView: View {
    let node: ExecutionStepNode
    let isLastRoot: Bool

    var body: some View {
        VStack(spacing: 0) {
            ExecutionStepChecklistRow(step: node.step, depth: node.depth)

            ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                ExecutionStepNodeView(node: child, isLastRoot: isLastRoot && index == node.children.count - 1)
            }

            if !isLastRoot {
                Divider()
                    .padding(.leading, 118 + CGFloat(node.depth * 22))
                    .overlay(NestTaskStyle.separator.opacity(0.85))
            }
        }
    }
}

private struct ExecutionStepChecklistRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var step: ExecutionStep
    let depth: Int

    private var leadingPadding: CGFloat {
        18 + CGFloat(depth * 24)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                step.isCompleted.toggle()
                step.completedAt = step.isCompleted ? .now : nil
                if let task = step.executionTask {
                    ProgressService.refreshCompletionState(for: task)
                }
            }
            try? modelContext.save()
        } label: {
            HStack(spacing: 14) {
                CircleCheckmark(isCompleted: step.isCompleted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.system(size: 17, weight: depth == 0 ? .semibold : .medium))
                        .foregroundStyle(step.isCompleted ? NestTaskStyle.secondary.opacity(0.72) : NestTaskStyle.ink)
                        .strikethrough(step.isCompleted, color: NestTaskStyle.secondary.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if depth > 0 {
                        Text("子タスク")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NestTaskStyle.secondary.opacity(0.72))
                    }
                }
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 18)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(step.title)
        .accessibilityValue(step.isCompleted ? "完了" : "未完了")
    }
}

struct ScheduleCard: View {
    let item: ScheduleItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text(item.dateLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.isToday ? NestTaskStyle.teal : NestTaskStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Circle()
                    .fill(item.isToday ? NestTaskStyle.teal : NestTaskStyle.separator)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 62)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconTile(systemName: item.iconName, tint: item.tint, size: 46, iconSize: 20)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(NestTaskStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(item.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NestTaskStyle.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer()

                    StatusBadge(text: item.status, tint: item.tint)
                }

                ProgressBar(progress: item.progress, height: 5)
            }
        }
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.045)
    }
}

private struct NavigableScheduleCard: View {
    let item: ScheduleItem
    let templates: [TaskTemplate]

    private var template: TaskTemplate? {
        guard let templateID = item.templateID else { return nil }
        return templates.first { $0.id == templateID }
    }

    var body: some View {
        if let template {
            NavigationLink {
                TemplateDetailView(template: template)
            } label: {
                ScheduleCard(item: item)
            }
            .buttonStyle(.plain)
            .accessibilityHint("テンプレート詳細を開きます")
        } else {
            ScheduleCard(item: item)
        }
    }
}

struct ScheduleEmptyCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NestTaskStyle.teal)
                .frame(width: 36, height: 36)
                .background(NestTaskStyle.tealSoft, in: Circle())

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NestTaskStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.025)
    }
}

struct TemplateCard: View {
    let template: TaskTemplate

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: template.iconName, tint: template.tint)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(template.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()

                    Text(template.stepCountText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NestTaskStyle.teal)
                }

                HStack(spacing: 8) {
                    StatusBadge(text: template.startModeLabel, tint: template.tint)

                    Text(template.metadataLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NestTaskStyle.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Text(template.descriptionText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NestTaskStyle.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.05)
    }
}

struct HistorySummaryCard: View {
    let completedCount: Int
    let incompleteCompletedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("今月の実行履歴", systemImage: "checkmark.seal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NestTaskStyle.secondary)

                Spacer()

                Text("\(completedCount)件")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(NestTaskStyle.teal)
            }

            HStack(spacing: 16) {
                HistoryMetric(value: "\(completedCount)件", label: "完了")
                Divider()
                    .frame(height: 38)
                HistoryMetric(value: "\(max(completedCount - incompleteCompletedCount, 0))件", label: "全完了")
                Divider()
                    .frame(height: 38)
                HistoryMetric(value: "\(incompleteCompletedCount)件", label: "未完あり")
            }
        }
        .taskCard(cornerRadius: 20, padding: 20, shadowOpacity: 0.06)
    }
}

struct HistoryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(NestTaskStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NestTaskStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistoryCard: View {
    let task: ExecutionTask

    private var completedAtLabel: String {
        guard let completedAt = task.completedAt else { return "完了日なし" }
        return DateHelpers.japaneseMonthDayWeekdayTime(completedAt)
    }

    private var progressPercentage: Int {
        Int((task.progress * 100).rounded())
    }

    private var countLabel: String {
        "\(task.completedCount) / \(task.totalCount)項目"
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: task.iconName, tint: task.tint, size: 48, iconSize: 21)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(task.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()

                    Text("\(progressPercentage)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(task.progress >= 1 ? NestTaskStyle.teal : NestTaskStyle.amber)
                }

                Text("\(countLabel)｜\(task.templateNameLabel)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NestTaskStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    Text(completedAtLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NestTaskStyle.secondary.opacity(0.82))

                    if task.progress < 1 {
                        StatusBadge(text: "未完了あり", tint: NestTaskStyle.amber)
                    }
                }
            }
        }
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.045)
    }
}

private struct EmptyHistoryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("完了した実行タスクはまだありません")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(NestTaskStyle.ink)

            Text("完了にしたタスクはここに残ります")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NestTaskStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCard(cornerRadius: 18, padding: 16, shadowOpacity: 0.045)
    }
}

struct CategorySelector: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selection = category
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selection == category ? .white : NestTaskStyle.secondary)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(selection == category ? NestTaskStyle.teal : NestTaskStyle.card)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selection == category ? NestTaskStyle.teal : NestTaskStyle.separator, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(NestTaskStyle.ink)
    }
}

struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct IconTile: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 54
    var iconSize: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))

            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

private struct CircleCheckmark: View {
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? NestTaskStyle.teal : .clear)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(isCompleted ? NestTaskStyle.teal : NestTaskStyle.secondary.opacity(0.55), lineWidth: 1.7)
                .frame(width: 28, height: 28)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct DashedGuide: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NestTaskStyle.track)

                if clampedProgress > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NestTaskStyle.teal, Color(red: 0.14, green: 0.68, blue: 0.64)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(height, proxy.size.width * clampedProgress))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }
}

private extension View {
    func taskCard(cornerRadius: CGFloat, padding: CGFloat, shadowOpacity: Double) -> some View {
        self
            .padding(padding)
            .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NestTaskStyle.separator.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 14, x: 0, y: 7)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .modelContainer(for: [
                TaskTemplate.self,
                TemplateStep.self,
                ExecutionTask.self,
                ExecutionStep.self
            ], inMemory: true)
    }
}
