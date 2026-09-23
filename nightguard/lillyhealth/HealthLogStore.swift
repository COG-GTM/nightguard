//
//  HealthLogStore.swift
//  nightguard
//
//  Single source of truth for the Lilly Health™-style logbook: food, weight,
//  activity, sleep and medication entries, persisted as JSON in UserDefaults.
//

import Foundation
import Combine

final class HealthLogStore: ObservableObject {

    static let shared = HealthLogStore()

    static let storageKey = "lillyHealth.logbook"
    static let defaultCalorieTarget = 1800
    static let defaultProteinTarget = 100
    /// A calorie deficit target sits this far below maintenance.
    static let deficitCalories = 500

    @Published private(set) var food: [FoodEntry] = []
    @Published private(set) var weights: [WeightEntry] = []
    @Published private(set) var activities: [ActivityEntry] = []
    @Published private(set) var sleep: [SleepEntry] = []
    @Published private(set) var medications: [MedicationEntry] = []
    @Published var calorieTarget: Int = HealthLogStore.defaultCalorieTarget {
        didSet { persist() }
    }
    @Published var proteinTarget: Int = HealthLogStore.defaultProteinTarget {
        didSet { persist() }
    }
    @Published var maintenanceCalories: Int = HealthLogStore.defaultCalorieTarget {
        didSet { persist() }
    }
    @Published var weightGoal: WeightGoal = .maintain {
        didSet { persist() }
    }

    private struct Snapshot: Codable {
        var food: [FoodEntry]
        var weights: [WeightEntry]
        var activities: [ActivityEntry]
        var sleep: [SleepEntry]
        var medications: [MedicationEntry]
        var calorieTarget: Int
        var proteinTarget: Int?
        var maintenanceCalories: Int?
        var weightGoal: WeightGoal?
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var isLoading = false

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, seedIfEmpty: Bool = true) {
        self.defaults = defaults
        self.calendar = calendar
        load()
        if seedIfEmpty && isEmpty {
            seedDemoData()
        }
    }

    var isEmpty: Bool {
        food.isEmpty && weights.isEmpty && activities.isEmpty && sleep.isEmpty && medications.isEmpty
    }

    // MARK: - Mutations

    func log(_ entry: FoodEntry) {
        food.append(entry)
        food.sort { $0.date > $1.date }
        persist()
    }

    func log(_ entry: WeightEntry) {
        weights.append(entry)
        weights.sort { $0.date > $1.date }
        persist()
    }

    func log(_ entry: ActivityEntry) {
        activities.append(entry)
        activities.sort { $0.date > $1.date }
        persist()
    }

    func log(_ entry: SleepEntry) {
        sleep.append(entry)
        sleep.sort { $0.date > $1.date }
        persist()
    }

    func log(_ entry: MedicationEntry) {
        medications.append(entry)
        medications.sort { $0.date > $1.date }
        persist()
    }

    func removeFood(id: UUID) {
        food.removeAll { $0.id == id }
        persist()
    }

    func removeAll() {
        food = []
        weights = []
        activities = []
        sleep = []
        medications = []
        calorieTarget = HealthLogStore.defaultCalorieTarget
        proteinTarget = HealthLogStore.defaultProteinTarget
        maintenanceCalories = HealthLogStore.defaultCalorieTarget
        weightGoal = .maintain
        persist()
    }

    // MARK: - Queries

    func food(on day: Date) -> [FoodEntry] {
        food.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func calories(on day: Date) -> Int {
        food(on: day).reduce(0) { $0 + $1.calories }
    }

    func protein(on day: Date) -> Int {
        food(on: day).reduce(0) { $0 + ($1.proteinGrams ?? 0) }
    }

    /// Calorie target implied by the goal: maintenance in `.maintain`, 500 under it in `.deficit`.
    var derivedCalorieTarget: Int {
        switch weightGoal {
        case .maintain: return maintenanceCalories
        case .deficit: return max(maintenanceCalories - HealthLogStore.deficitCalories, 1000)
        }
    }

    /// Resets the calorie target to the one implied by the current goal, discarding any override.
    func applyDerivedCalorieTarget() {
        calorieTarget = derivedCalorieTarget
    }

    var isCalorieTargetOverridden: Bool { calorieTarget != derivedCalorieTarget }

    /// "500 under maintenance today" / "on target"
    var calorieGoalCopy: String {
        switch weightGoal {
        case .deficit:
            return "\(max(maintenanceCalories - calorieTarget, 0)) under maintenance today"
        case .maintain:
            return "on target"
        }
    }

    func activities(on day: Date) -> [ActivityEntry] {
        activities.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func activeMinutes(on day: Date) -> Int {
        activities(on: day).reduce(0) { $0 + $1.minutes }
    }

    func weight(on day: Date) -> WeightEntry? {
        weights.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func sleep(on day: Date) -> SleepEntry? {
        sleep.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func medications(on day: Date) -> [MedicationEntry] {
        medications.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    var latestWeight: WeightEntry? { weights.first }

    var startingWeight: WeightEntry? { weights.last }

    var lastDose: MedicationEntry? { medications.first }

    /// Next scheduled injection, one dosing interval after the last dose.
    var nextDoseDate: Date? {
        guard let last = lastDose else { return nil }
        return calendar.date(byAdding: .day, value: ZepboundDose.dosingIntervalDays, to: last.date)
    }

    /// True when no dose has been logged yet or the next dose is due today or overdue.
    func isDosingDay(_ day: Date = Date()) -> Bool {
        guard let next = nextDoseDate else { return true }
        return calendar.startOfDay(for: next) <= calendar.startOfDay(for: day)
    }

    func hasEntries(on day: Date) -> Bool {
        !food(on: day).isEmpty
            || weight(on: day) != nil
            || !activities(on: day).isEmpty
            || sleep(on: day) != nil
            || !medications(on: day).isEmpty
    }

    /// Days with at least one entry, as start-of-day dates.
    var daysWithEntries: Set<Date> {
        var days = Set<Date>()
        food.forEach { days.insert(calendar.startOfDay(for: $0.date)) }
        weights.forEach { days.insert(calendar.startOfDay(for: $0.date)) }
        activities.forEach { days.insert(calendar.startOfDay(for: $0.date)) }
        sleep.forEach { days.insert(calendar.startOfDay(for: $0.date)) }
        medications.forEach { days.insert(calendar.startOfDay(for: $0.date)) }
        return days
    }

    /// Consecutive days ending today (or yesterday, if today has nothing yet) with an entry.
    func entryStreak(asOf day: Date = Date()) -> Int {
        let days = daysWithEntries
        var cursor = calendar.startOfDay(for: day)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Weekly dose history (oldest first) for the Trends chart.
    func doseHistory(weeks: Int) -> [MedicationEntry] {
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else { return [] }
        return medications.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    /// Weight history (oldest first) for the Trends chart.
    func weightHistory(days: Int) -> [WeightEntry] {
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        return weights.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    /// Weight history for a single clothing state, so clothed and unclothed trends stay separate.
    func weightHistory(days: Int, state: WeighInState) -> [WeightEntry] {
        weightHistory(days: days).filter { $0.state == state }
    }

    func latestWeight(state: WeighInState) -> WeightEntry? {
        weights.first { $0.state == state }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: HealthLogStore.storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        isLoading = true
        food = snapshot.food
        weights = snapshot.weights
        activities = snapshot.activities
        sleep = snapshot.sleep
        medications = snapshot.medications
        calorieTarget = snapshot.calorieTarget
        proteinTarget = snapshot.proteinTarget ?? HealthLogStore.defaultProteinTarget
        maintenanceCalories = snapshot.maintenanceCalories ?? snapshot.calorieTarget
        weightGoal = snapshot.weightGoal ?? .maintain
        isLoading = false
    }

    private func persist() {
        guard !isLoading else { return }
        let snapshot = Snapshot(
            food: food,
            weights: weights,
            activities: activities,
            sleep: sleep,
            medications: medications,
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            maintenanceCalories: maintenanceCalories,
            weightGoal: weightGoal
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: HealthLogStore.storageKey)
        }
    }

    // MARK: - Demo seed

    /// Ten weeks of a plausible Zepbound® titration so the dashboard has trends on first launch.
    private func seedDemoData() {
        let now = Date()
        let today = calendar.startOfDay(for: now)

        func daysAgo(_ days: Int, hour: Int = 8) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }

        // Weekly doses: 4 weeks at 2.5 mg, 4 weeks at 5 mg, then 7.5 mg. Last dose a week ago
        // so today reads as a dosing day.
        let titration: [Double] = [2.5, 2.5, 2.5, 2.5, 5, 5, 5, 5, 7.5, 7.5]
        for (index, dose) in titration.enumerated() {
            let weeksAgo = titration.count - index
            medications.append(MedicationEntry(
                date: daysAgo(weeksAgo * 7, hour: 9),
                medication: ZepboundDose.productName,
                doseMg: dose,
                injectionSite: ZepboundDose.injectionSites[index % ZepboundDose.injectionSites.count]
            ))
        }

        // Weekly weigh-ins drifting from 238 lbs to 224 lbs, morning unclothed plus an
        // evening clothed reading that runs a few pounds heavy.
        let weightsLbs: [Double] = [238.4, 237.1, 235.8, 234.6, 233.0, 231.2, 229.5, 227.9, 226.4, 225.1, 224.0]
        for (index, pounds) in weightsLbs.enumerated() {
            let daysBack = (weightsLbs.count - 1 - index) * 7
            weights.append(WeightEntry(date: daysAgo(daysBack, hour: 7), pounds: pounds, state: .unclothed))
            weights.append(WeightEntry(date: daysAgo(daysBack, hour: daysBack == 0 ? 6 : 19),
                                       pounds: pounds + 2.6, state: .clothed))
        }

        // The last few days of meals, movement and sleep.
        food.append(FoodEntry(date: daysAgo(0, hour: 8), name: "Avocado Toast and Eggs", calories: 200, meal: .breakfast, proteinGrams: 14))
        food.append(FoodEntry(date: daysAgo(0, hour: 12), name: "Grilled Chicken Salad", calories: 430, meal: .lunch, proteinGrams: 38))
        food.append(FoodEntry(date: daysAgo(1, hour: 8), name: "Greek Yogurt and Berries", calories: 180, meal: .breakfast, proteinGrams: 18))
        food.append(FoodEntry(date: daysAgo(1, hour: 13), name: "Turkey Wrap", calories: 410, meal: .lunch, proteinGrams: 32))
        food.append(FoodEntry(date: daysAgo(1, hour: 19), name: "Salmon and Roasted Vegetables", calories: 560, meal: .dinner, proteinGrams: 44))
        food.append(FoodEntry(date: daysAgo(2, hour: 8), name: "Oatmeal with Almonds", calories: 320, meal: .breakfast, proteinGrams: 12))
        food.append(FoodEntry(date: daysAgo(2, hour: 19), name: "Chicken Stir-Fry", calories: 520, meal: .dinner, proteinGrams: 41))

        activities.append(ActivityEntry(date: daysAgo(0, hour: 7), name: "Morning Walk", minutes: 32, category: .walk, miles: 1.6))
        activities.append(ActivityEntry(date: daysAgo(1, hour: 18), name: "Strength Training", minutes: 45, category: .strength, weightLbs: 45))
        activities.append(ActivityEntry(date: daysAgo(2, hour: 7), name: "Morning Run", minutes: 28, category: .run, miles: 3.2))
        activities.append(ActivityEntry(date: daysAgo(3, hour: 17), name: "Cycling", minutes: 40, category: .cycling, miles: 9.4))

        sleep.append(SleepEntry(date: daysAgo(0, hour: 6), hours: 7.4))
        sleep.append(SleepEntry(date: daysAgo(1, hour: 6), hours: 6.8))
        sleep.append(SleepEntry(date: daysAgo(2, hour: 6), hours: 7.9))

        maintenanceCalories = 2300
        weightGoal = .deficit
        calorieTarget = derivedCalorieTarget
        proteinTarget = HealthLogStore.defaultProteinTarget

        food.sort { $0.date > $1.date }
        weights.sort { $0.date > $1.date }
        activities.sort { $0.date > $1.date }
        sleep.sort { $0.date > $1.date }
        medications.sort { $0.date > $1.date }
        persist()
    }
}
