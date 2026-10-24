import XCTest
@testable import NezhnyRitm

@MainActor
final class JournalTests: XCTestCase {
    private func store(start: Date = Date()) -> JournalStore {
        let repo = Repository(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("journal.json"))
        var data = AppData(); data.startDay = DayKey.string(start)
        try! repo.save(data)
        return JournalStore(repository: repo)
    }
    private var sunday: Date { DayKey.date("2026-10-25")! }

    func testSeedMatchesRequestedProgram() throws {
        let plans = SeedProgram.make()
        XCTAssertEqual(plans.map(\.weekday), Array(1...7))
        XCTAssertEqual(plans.map { $0.exercises.count }, [5, 0, 5, 0, 5, 0, 0])
        XCTAssertEqual(plans[0].exercises.map(\.sets), [2, 3, 2, 2, 2])
        XCTAssertEqual(plans[2].exercises.filter(\.optional).map(\.name), ["Тяга фитнес-резинки"])
        XCTAssertFalse(plans.flatMap(\.exercises).contains { $0.name.lowercased().contains("отжим") })
        _ = try AppData().validated()
    }
    func testCompletionDoesNotRequireOptionalBandAndPersists() throws {
        let s = store()
        let tuesday = DayKey.adding(2, to: sunday)
        for e in s.session(on: tuesday).exercises where !e.optional {
            for index in 0..<e.sets { s.toggleSet(e, index: index, on: tuesday) }
        }
        XCTAssertTrue(s.session(on: tuesday).isComplete)
        XCTAssertEqual(s.session(on: tuesday).progress, 1)
        let reloaded = JournalStore(repository: s.repository)
        XCTAssertTrue(reloaded.session(on: tuesday).isComplete)
        let exercise = reloaded.session(on: tuesday).exercises[0]
        reloaded.toggleSet(exercise, index: 0, on: tuesday)
        XCTAssertFalse(reloaded.session(on: tuesday).isComplete)
    }
    func testEditingPlanPreservesHistory() {
        let yesterday = DayKey.adding(-1, to: Date())
        let s = store(start: yesterday)
        let original = s.session(on: yesterday)
        var plan = s.plan(on: yesterday)
        plan.title = "Новое занятие"; plan.exercises = []
        s.savePlan(plan)
        XCTAssertEqual(s.session(on: yesterday), original)
        XCTAssertEqual(s.plan(on: yesterday).title, "Новое занятие")
    }
    func testMoveKeepsMealsAndRejectsOccupiedDay() throws {
        let s = store()
        let futureSunday = (1...14).map { DayKey.adding($0, to: Date()) }.first { DayKey.calendar.component(.weekday, from: $0) == 1 }!
        let monday = DayKey.adding(1, to: futureSunday)
        let tuesday = DayKey.adding(2, to: futureSunday)
        let meal = Meal(category: "Обед", text: "Суп")
        s.updateDay(monday) { $0.meals = [meal]; $0.manualSteps = 1234 }
        XCTAssertThrowsError(try s.moveWorkout(from: futureSunday, to: tuesday))
        try s.moveWorkout(from: futureSunday, to: monday)
        XCTAssertEqual(s.session(on: futureSunday).movedTo, DayKey.string(monday))
        XCTAssertEqual(s.session(on: monday).exercises.count, 5)
        XCTAssertEqual(s.record(on: monday).meals, [meal])
        XCTAssertEqual(s.record(on: monday).steps, 1234)
    }
    func testBackupRoundTripIncludingPhotosAndManualZero() throws {
        let s = store()
        s.updateDay(Date()) {
            $0.meals = [Meal(category: "Свой приём", text: "Рис", photo: Data([1, 2, 3]))]
            $0.manualSteps = 0; $0.healthSteps = 100; $0.wellbeing = "Спокойно"
        }
        let bytes = try Repository.encode(s.data)
        XCTAssertEqual(try Repository.decode(bytes), s.data)
        XCTAssertEqual(s.record(on: Date()).steps, 0)
        let other = store()
        try other.importBackup(Repository.decode(bytes))
        XCTAssertEqual(other.data, s.data)
        let files = try FileManager.default.contentsOfDirectory(atPath: other.repository.url.deletingLastPathComponent().path)
        XCTAssertTrue(files.contains { $0.hasPrefix("before-import-") })
    }
    func testInvalidBackupDoesNotModifyJournal() throws {
        let s = store()
        let previous = s.data
        var invalid = previous
        invalid.version = 99
        XCTAssertThrowsError(try s.importBackup(invalid))
        invalid = previous; invalid.schedule[0].exercises[0].sets = -1
        XCTAssertThrowsError(try s.importBackup(invalid))
        invalid = previous; invalid.days["2026-02-30"] = DayRecord()
        XCTAssertThrowsError(try s.importBackup(invalid))
        XCTAssertEqual(s.data, previous)
        XCTAssertEqual(try s.repository.load(), previous)
    }
    func testCorruptFileIsNotOverwritten() throws {
        let s = store()
        let bytes = Data("broken json".utf8)
        try bytes.write(to: s.repository.url)
        let reloaded = JournalStore(repository: s.repository)
        XCTAssertTrue(reloaded.recoveryRequired)
        reloaded.updateDay(Date()) { $0.comment = "Не должно перезаписать файл" }
        XCTAssertEqual(try Data(contentsOf: s.repository.url), bytes)
    }
    func testReportContainsUserDataAndNoAutomaticDeliveryClaim() {
        let s = store()
        s.updateDay(Date()) { $0.meals = [Meal(category: "Ужин", text: "Паста")]; $0.manualSteps = 567; $0.wellbeing = "Хорошо"; $0.comment = "Погуляла" }
        let report = s.report(on: Date())
        for text in ["Отчёт для Астраси", "Паста", "567", "Хорошо", "Погуляла", "по моему желанию"] { XCTAssertTrue(report.contains(text)) }
    }
}
