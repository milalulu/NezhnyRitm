import XCTest
@testable import NezhnyRitm

@MainActor
final class WellnessTests: XCTestCase {
    private func store() throws -> JournalStore {
        let repo = Repository(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json"))
        try repo.save(AppData())
        return JournalStore(repository: repo)
    }
    func testV1FileMigrationKeepsPhotosIDsHistoryAndOriginalBackup() throws {
        let s = try store()
        let date = Date(), key = DayKey.string(date)
        s.updateDay(date) { $0.meals = [Meal(category: "Ужин", text: "Суп", photo: Data([7, 8, 9]))]; $0.manualSteps = 0; $0.comment = "Личная заметка" }
        let old = s.data
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Repository.encode(old)) as? [String: Any])
        json["version"] = 1; json.removeValue(forKey: "wellness")
        var days = try XCTUnwrap(json["days"] as? [String: [String: Any]])
        for id in days.keys { days[id]?.removeValue(forKey: "details") }
        json["days"] = days
        let bytes = try JSONSerialization.data(withJSONObject: json)
        try bytes.write(to: s.repository.url)
        let loaded = try s.repository.load()
        XCTAssertEqual(loaded.version, 2)
        XCTAssertNotNil(loaded.wellness)
        XCTAssertEqual(loaded.schedule, old.schedule)
        XCTAssertEqual(loaded.days[key]?.workout, old.days[key]?.workout)
        XCTAssertEqual(loaded.days[key]?.meals, old.days[key]?.meals)
        XCTAssertEqual(loaded.days[key]?.manualSteps, 0)
        XCTAssertEqual(loaded.days[key]?.comment, "Личная заметка")
        let backup = s.repository.url.deletingLastPathComponent().appendingPathComponent("v1-before-upgrade.json")
        XCTAssertEqual(try Data(contentsOf: backup), bytes)
        XCTAssertEqual(try s.repository.load(), loaded)
    }
    func testRoutineRewardsSurviveUncheckingAndPurchasesArePersistent() throws {
        let s = try store(), date = Date()
        let r = s.wellness.routines[0]
        s.toggleRoutine(r, on: date)
        s.toggleRoutine(r, on: date)
        s.toggleRoutine(r, on: date)
        XCTAssertEqual(s.wellness.pet.hearts, 1)
        for i in 1...2 { s.toggleRoutine(s.wellness.routines[i], on: date) }
        let bow = PetItem.catalog.first { $0.id == "bow" }!
        s.buy(bow); s.equip(bow)
        XCTAssertEqual(s.wellness.pet.hearts, 0)
        XCTAssertEqual(s.wellness.pet.accessory, "bow")
        s.toggleRoutine(r, on: date)
        XCTAssertEqual(s.wellness.pet.hearts, 0)
        let reloaded = JournalStore(repository: s.repository)
        XCTAssertEqual(reloaded.wellness.pet, s.wellness.pet)
        s.buy(PetItem.catalog.first { $0.id == "crown" }!)
        XCTAssertFalse(s.wellness.pet.owned.contains("crown"))
        XCTAssertNotNil(s.error)
    }
    func testMovingRoutineDoesNotMoveFoodAndKeepsPastSnapshot() throws {
        let s = try store()
        let yesterday = DayKey.adding(-1, to: Date()), tomorrow = DayKey.adding(1, to: Date())
        let weekday = DayKey.calendar.component(.weekday, from: yesterday)
        var r = Routine(title: "Мой ритуал", weekdays: [weekday], createdDay: DayKey.string(yesterday))
        s.saveRoutine(r); s.reconcileRoutines()
        s.updateDay(tomorrow) { $0.meals = [Meal(category: "Обед", text: "Паста")] }
        try s.moveRoutine(r, from: yesterday, to: tomorrow)
        XCTAssertFalse(s.routines(on: yesterday).contains { $0.id == r.id })
        XCTAssertTrue(s.routines(on: tomorrow).contains { $0.id == r.id })
        XCTAssertEqual(s.record(on: tomorrow).meals.first?.text, "Паста")
        XCTAssertThrowsError(try s.moveRoutine(r, from: yesterday, to: tomorrow))
        r.weekdays = Set(1...7); s.saveRoutine(r)
        XCTAssertFalse(s.routines(on: yesterday).contains { $0.id == r.id })
    }
    func testSleepUnionClipsDuplicatesAndManualEntryWins() throws {
        let start = Date(timeIntervalSince1970: 0)
        func interval(_ a: Double, _ b: Double) -> DateInterval { DateInterval(start: start.addingTimeInterval(a * 3600), end: start.addingTimeInterval(b * 3600)) }
        let hours = SleepMath.hours(intervals: [interval(-2, 4), interval(2, 8), interval(10, 12), interval(10, 12)], within: interval(0, 11))
        XCTAssertEqual(hours, 9)
        XCTAssertNil(SleepMath.hours(intervals: [], within: interval(0, 24)))
        let s = try store()
        s.updateDetails(on: Date()) { $0.healthSleepHours = 9 }
        s.saveSleep(SleepEntry(start: start, end: start.addingTimeInterval(7 * 3600), quality: 4, note: "Выспалась"), on: Date())
        XCTAssertEqual(s.record(on: Date()).details?.sleepHours, 7)
        s.saveSleep(nil, on: Date())
        XCTAssertEqual(s.record(on: Date()).details?.sleepHours, 9)
    }
    func testSessionCustomizationCannotEraseDoneSetsOrChangeWeeklyPlan() throws {
        let s = try store()
        let sunday = DayKey.date("2026-10-25")!
        var e = s.session(on: sunday).exercises[0]
        let original = s.plan(on: sunday)
        s.toggleSet(e, index: 1, on: sunday)
        e.sets = 1; s.customizeExercise(e, on: sunday)
        XCTAssertNotNil(s.error)
        XCTAssertEqual(s.session(on: sunday).exercises[0].sets, 2)
        s.error = nil; e.sets = 3; e.repetitions = "6"; s.customizeExercise(e, on: sunday)
        XCTAssertNil(s.error)
        XCTAssertEqual(s.session(on: sunday).exercises[0].repetitions, "6")
        XCTAssertEqual(s.plan(on: sunday), original)
    }
    func testWeeklyReportAndBackupContainNewDataWithoutInventedRatings() throws {
        let s = try store(), date = Date()
        let meal = Meal(category: "Обед", text: "Паста", photo: Data([1, 2]), details: MealDetails(satiety: "Комфортная сытость", feeling: "Спокойно"))
        s.updateDay(date) { $0.meals = [meal] }
        s.addFavorite(meal); s.addFavorite(meal)
        XCTAssertEqual(s.wellness.favorites.count, 1)
        s.updateDetails(on: date) { $0.mood = 4 }
        let text = s.periodReport(ending: date, days: 7)
        for phrase in ["Недельный отчёт", "Паста", "Комфортная сытость", "4/5", "Сон: не записан", "Настроение: не записано"] { XCTAssertTrue(text.contains(phrase), phrase) }
        let copy = try Repository.decode(Repository.encode(s.data))
        XCTAssertEqual(copy, s.data)
        XCTAssertEqual(copy.wellness?.favorites.first?.photo, Data([1, 2]))
    }
    func testInvalidSleepAndUnknownRoutineCannotReplaceJournal() throws {
        let s = try store(), previous = s.data
        var invalid = previous
        invalid.days[DayKey.string(Date())]?.details?.healthSleepHours = -2
        XCTAssertThrowsError(try s.importBackup(invalid))
        invalid = previous
        invalid.days[DayKey.string(Date())]?.details?.completedRoutines = [UUID()]
        XCTAssertThrowsError(try s.importBackup(invalid))
        XCTAssertEqual(s.data, previous)
    }
}
