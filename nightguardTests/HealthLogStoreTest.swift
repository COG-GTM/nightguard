//
//  HealthLogStoreTest.swift
//  nightguardTests
//

import XCTest

class HealthLogStoreTest: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "HealthLogStoreTest"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore(seed: Bool = false) -> HealthLogStore {
        HealthLogStore(defaults: defaults, seedIfEmpty: seed)
    }

    func testStartsEmptyWithoutSeed() {
        let store = makeStore()
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.calorieTarget, HealthLogStore.defaultCalorieTarget)
        XCTAssertTrue(store.isDosingDay())
        XCTAssertEqual(store.entryStreak(), 0)
    }

    func testSeedProducesTitrationAndTodayIsDosingDay() {
        let store = makeStore(seed: true)
        XCTAssertFalse(store.isEmpty)
        XCTAssertEqual(store.medications.count, 10)
        XCTAssertEqual(store.lastDose?.doseMg, 7.5)
        XCTAssertTrue(store.isDosingDay())
        XCTAssertEqual(store.latestWeight?.pounds, 224.0)
        XCTAssertEqual(store.startingWeight?.pounds, 238.4)
    }

    func testCaloriesAreSummedPerDay() {
        let store = makeStore()
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        store.log(FoodEntry(date: now, name: "Eggs", calories: 200, meal: .breakfast))
        store.log(FoodEntry(date: now, name: "Salad", calories: 430, meal: .lunch))
        store.log(FoodEntry(date: yesterday, name: "Pasta", calories: 700, meal: .dinner))

        XCTAssertEqual(store.calories(on: now), 630)
        XCTAssertEqual(store.calories(on: yesterday), 700)
        XCTAssertEqual(store.food(on: now).count, 2)
    }

    func testNextDoseIsOneWeekAfterLastDose() {
        let store = makeStore()
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!

        store.log(MedicationEntry(date: threeDaysAgo, medication: "Zepbound", doseMg: 5, injectionSite: "Abdomen"))

        let expected = calendar.date(byAdding: .day, value: 7, to: threeDaysAgo)!
        XCTAssertEqual(store.nextDoseDate, expected)
        XCTAssertFalse(store.isDosingDay())
    }

    func testEntryStreakCountsConsecutiveDays() {
        let store = makeStore()
        let calendar = Calendar.current
        let today = Date()
        for daysBack in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -daysBack, to: today)!
            store.log(WeightEntry(date: day, pounds: 230 - Double(daysBack)))
        }
        // gap on day -3, entry on day -4 must not extend the streak
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        store.log(ActivityEntry(date: fourDaysAgo, name: "Walk", minutes: 20))

        XCTAssertEqual(store.entryStreak(asOf: today), 3)
    }

    func testEntriesRoundTripThroughUserDefaults() {
        let store = makeStore()
        store.log(WeightEntry(date: Date(), pounds: 221.6))
        store.log(SleepEntry(date: Date(), hours: 7.5))
        store.calorieTarget = 1650

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.latestWeight?.pounds, 221.6)
        XCTAssertEqual(reloaded.sleep.first?.hours, 7.5)
        XCTAssertEqual(reloaded.calorieTarget, 1650)
    }

    func testRemoveAllClearsEverything() {
        let store = makeStore(seed: true)
        store.removeAll()
        XCTAssertTrue(store.isEmpty)
        XCTAssertTrue(makeStore().isEmpty)
    }

    func testProteinIsSummedPerDayAndIgnoresUnloggedMeals() {
        let store = makeStore()
        let now = Date()

        store.log(FoodEntry(date: now, name: "Eggs", calories: 200, meal: .breakfast, proteinGrams: 14))
        store.log(FoodEntry(date: now, name: "Salad", calories: 430, meal: .lunch, proteinGrams: 38))
        store.log(FoodEntry(date: now, name: "Apple", calories: 95, meal: .snack))

        XCTAssertEqual(store.protein(on: now), 52)
        XCTAssertEqual(store.calories(on: now), 725)
        XCTAssertEqual(store.proteinTarget, HealthLogStore.defaultProteinTarget)
    }

    func testWeightHistoryIsFilteredByWeighInState() {
        let store = makeStore()
        let calendar = Calendar.current
        for daysBack in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -daysBack, to: Date())!
            store.log(WeightEntry(date: day, pounds: 220 - Double(daysBack), state: .unclothed))
            store.log(WeightEntry(date: day, pounds: 223 - Double(daysBack), state: .clothed))
        }

        XCTAssertEqual(store.weightHistory(days: 7, state: .unclothed).map { $0.pounds }, [218, 219, 220])
        XCTAssertEqual(store.weightHistory(days: 7, state: .clothed).map { $0.pounds }, [221, 222, 223])
        XCTAssertEqual(store.latestWeight(state: .clothed)?.pounds, 223)
    }

    func testWeightEntryDefaultsToUnclothedWhenStateIsAbsent() throws {
        let json = Data("""
        {"id":"\(UUID().uuidString)","date":0,"pounds":212.4}
        """.utf8)
        let entry = try JSONDecoder().decode(WeightEntry.self, from: json)
        XCTAssertEqual(entry.state, .unclothed)
        XCTAssertEqual(entry.pounds, 212.4)
    }

    func testDeficitGoalDerivesTargetBelowMaintenance() {
        let store = makeStore()
        store.maintenanceCalories = 2300

        store.weightGoal = .maintain
        XCTAssertEqual(store.derivedCalorieTarget, 2300)
        store.applyDerivedCalorieTarget()
        XCTAssertEqual(store.calorieGoalCopy, "on target")

        store.weightGoal = .deficit
        XCTAssertEqual(store.derivedCalorieTarget, 1800)
        store.applyDerivedCalorieTarget()
        XCTAssertFalse(store.isCalorieTargetOverridden)
        XCTAssertEqual(store.calorieGoalCopy, "500 under maintenance today")

        store.calorieTarget = 1700
        XCTAssertTrue(store.isCalorieTargetOverridden)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.weightGoal, .deficit)
        XCTAssertEqual(reloaded.maintenanceCalories, 2300)
        XCTAssertEqual(reloaded.calorieTarget, 1700)
    }

    func testActivityCategoryMeasuresAndSummaries() {
        let run = ActivityEntry(date: Date(), name: "Morning Run", minutes: 28, category: .run, miles: 3.2)
        let strength = ActivityEntry(date: Date(), name: "Strength Training", minutes: 45, category: .strength, weightLbs: 45)
        let yoga = ActivityEntry(date: Date(), name: "Yoga", minutes: 30, category: .yoga)

        XCTAssertEqual(run.summary, "Run · 3.2 mi · 28 min")
        XCTAssertEqual(strength.summary, "Strength · 45 lb dumbbells · 45 min")
        XCTAssertEqual(yoga.summary, "Yoga · 30 min")
        XCTAssertEqual(ActivityCategory.cycling.measure, .distance)
        XCTAssertEqual(ActivityCategory.strength.measure, .load)
        XCTAssertEqual(ActivityCategory.swim.measure, .duration)
    }

    func testLegacyActivityDecodesWithInferredCategory() throws {
        let json = Data("""
        {"id":"\(UUID().uuidString)","date":0,"name":"Morning Walk","minutes":32}
        """.utf8)
        let entry = try JSONDecoder().decode(ActivityEntry.self, from: json)
        XCTAssertEqual(entry.category, .walk)
        XCTAssertNil(entry.miles)
        XCTAssertNil(entry.weightLbs)
        XCTAssertEqual(entry.summary, "Walk · 32 min")
    }

    func testMilligramFormatting() {
        XCTAssertEqual(2.5.mgString, "2.5 mg")
        XCTAssertEqual(5.0.mgString, "5 mg")
        XCTAssertEqual(12.5.mgString, "12.5 mg")
    }
}
