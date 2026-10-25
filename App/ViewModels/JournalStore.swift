import Foundation
import Combine

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var selectedDate = Date()
    @Published var error: String?
    @Published private(set) var recoveryRequired = false
    let repository: Repository

    init(repository: Repository = .live) {
        self.repository = repository
        do { data = try repository.load() }
        catch {
            data = AppData()
            recoveryRequired = true
            self.error = "Не удалось прочитать дневник. Исходный файл сохранён. Импортируйте резервную копию в настройках. \(error.localizedDescription)"
        }
        reconcileHistory()
        reconcileRoutines()
    }

    func record(on date: Date) -> DayRecord { data.days[DayKey.string(date)] ?? DayRecord() }
    func plan(on date: Date) -> WorkoutPlan {
        data.schedule.first { $0.weekday == DayKey.calendar.component(.weekday, from: date) }!
    }
    func session(on date: Date) -> WorkoutSession {
        record(on: date).workout ?? WorkoutSession(title: plan(on: date).title, exercises: plan(on: date).exercises)
    }
    func commit(_ newData: AppData) {
        guard !recoveryRequired else {
            error = "Сначала восстановите дневник в настройках. Исходный файл защищён от перезаписи."
            return
        }
        do { try repository.save(newData); data = newData; WidgetPublisher.publish(newData) }
        catch { self.error = "Не удалось сохранить изменения: \(error.localizedDescription)" }
    }
    // Materialize past days before changing the recurring schedule.
    func reconcileHistory(now: Date = Date()) {
        guard !recoveryRequired, var cursor = DayKey.date(data.startDay) else { return }
        let end = DayKey.calendar.startOfDay(for: now)
        var updated = data
        var count = 0
        while cursor <= end && count < 40000 {
            let key = DayKey.string(cursor)
            var day = updated.days[key] ?? DayRecord()
            if day.workout == nil {
                let plan = plan(on: cursor)
                day.workout = WorkoutSession(title: plan.title, exercises: plan.exercises)
                updated.days[key] = day
            }
            cursor = DayKey.adding(1, to: cursor)
            count += 1
        }
        if updated != data { commit(updated) }
    }
    func updateDay(_ date: Date, change: (inout DayRecord) -> Void) {
        var next = data
        let key = DayKey.string(date)
        var day = record(on: date)
        change(&day)
        next.days[key] = day
        commit(next)
    }
    func toggleSet(_ exercise: Exercise, index: Int, on date: Date) {
        var session = session(on: date)
        guard session.movedTo == nil, (0..<exercise.sets).contains(index) else { return }
        var sets = session.completed[exercise.id.uuidString] ?? []
        if sets.contains(index) { sets.remove(index) } else { sets.insert(index) }
        session.completed[exercise.id.uuidString] = sets
        session.skipped = false
        var next = data
        var day = record(on: date); day.workout = session
        next.days[DayKey.string(date)] = day
        if session.isComplete {
            var w = wellness
            w.pet.rewardKeys.insert("workout:\(DayKey.string(date))")
            next.wellness = w
        }
        commit(next)
    }
    func toggleSkip(on date: Date) {
        var session = session(on: date)
        session.skipped.toggle()
        updateDay(date) { $0.workout = session }
    }
    func savePlan(_ plan: WorkoutPlan) {
        reconcileHistory()
        reconcileRoutines()
        var next = data
        guard let i = next.schedule.firstIndex(where: { $0.weekday == plan.weekday }) else { return }
        next.schedule[i] = plan
        // An untouched session today may adopt the edited plan. Past sessions never do.
        let today = DayKey.string(Date())
        if let session = next.days[today]?.workout, session.doneCount == 0, !session.skipped,
           session.movedFrom == nil, session.movedTo == nil,
           DayKey.calendar.component(.weekday, from: Date()) == plan.weekday {
            next.days[today]?.workout = WorkoutSession(title: plan.title, exercises: plan.exercises)
        }
        commit(next)
    }
    func moveWorkout(from source: Date, to destination: Date) throws {
        guard DayKey.string(source) != DayKey.string(destination),
              DayKey.calendar.startOfDay(for: destination) >= DayKey.calendar.startOfDay(for: Date()) else { throw DataError.sameDay }
        var original = session(on: source)
        guard original.doneCount == 0, original.movedTo == nil, !original.exercises.isEmpty else { throw DataError.startedWorkout }
        let target = session(on: destination)
        guard target.exercises.isEmpty && target.movedTo == nil else { throw DataError.moveConflict }
        var next = data
        var sourceDay = record(on: source)
        var targetDay = record(on: destination)
        original.skipped = false
        var moved = original
        original.movedTo = DayKey.string(destination)
        moved.movedFrom = DayKey.string(source)
        sourceDay.workout = original
        targetDay.workout = moved
        next.days[DayKey.string(source)] = sourceDay
        next.days[DayKey.string(destination)] = targetDay
        commit(next)
    }
    func setPreferences(_ preferences: Preferences) {
        var next = data
        next.preferences = preferences
        commit(next)
    }
    func status(on date: Date) -> String {
        let s = session(on: date)
        if let target = s.movedTo { return "Перенесено на \(target)" }
        if s.exercises.isEmpty { return s.title }
        if s.isComplete { return "Выполнено" }
        if s.skipped { return "Пропущено — можно продолжить" }
        if s.doneCount > 0 { return "Часть подходов выполнена" }
        if DayKey.string(date) < data.startDay { return "До начала дневника" }
        if DayKey.calendar.startOfDay(for: date) < DayKey.calendar.startOfDay(for: Date()) { return "Пропущено — новый день, новый ритм" }
        return "В вашем темпе"
    }
    func importBackup(_ imported: AppData) throws {
        let valid = try imported.migrated()
        _ = try repository.safetyCopy()
        try repository.save(valid)
        data = valid
        recoveryRequired = false
        reconcileHistory()
        reconcileRoutines()
    }
    func backupURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NezhnyRitm-\(DayKey.string(Date())).json")
        if recoveryRequired {
            try Data(contentsOf: repository.url).write(to: url, options: .atomic)
        } else { try Repository.encode(data).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        return url
    }
    func report(on date: Date) -> String {
        let day = record(on: date)
        let session = session(on: date)
        var lines = ["Отчёт для Астраси", DayKey.title(date), "", "Движение: \(session.title)", status(on: date)]
        for exercise in session.exercises {
            let done = session.completed[exercise.id.uuidString]?.count ?? 0
            lines.append("• \(exercise.name): \(done)/\(exercise.sets) подходов × \(exercise.repetitions)\(exercise.optional ? " (по желанию)" : "")")
        }
        let missed = DayKey.week(ending: date).filter {
            let s = self.session(on: $0)
            return DayKey.string($0) >= data.startDay && !s.exercises.isEmpty && !s.isComplete && s.movedTo == nil &&
                (s.skipped || DayKey.calendar.startOfDay(for: $0) < DayKey.calendar.startOfDay(for: Date()))
        }
        lines += ["", "Незавершённые и пропущенные занятия за 7 дней: " + (missed.isEmpty ? "нет" : missed.map(DayKey.string).joined(separator: ", ")), "", "Питание:"]
        lines += day.meals.isEmpty ? ["Пока нет записей"] : day.meals.map { "• \($0.category): \($0.text.isEmpty ? "Фото без описания" : $0.text)" }
        lines += ["", "Шаги: \(day.steps.map(String.init) ?? "нет данных")\(day.manualSteps != nil ? " (вручную)" : "")",
                  "Энергия: \(day.energy.map { "\($0)/5" } ?? "не записана")", "Самочувствие: \(day.wellbeing.isEmpty ? "не записано" : day.wellbeing)",
                  "Комментарий: \(day.comment.isEmpty ? "нет" : day.comment)", "", "Поддержи меня доброжелательно, без оценок еды, внешности и пропусков. Нагрузку увеличиваем только по моему желанию."]
        return lines.joined(separator: "\n")
    }
}
