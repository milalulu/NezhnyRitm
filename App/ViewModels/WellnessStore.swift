import Foundation

extension JournalStore {
    var wellness: WellnessData { data.wellnessValue }
    func updateWellness(_ change: (inout WellnessData) -> Void) {
        var next = data
        var w = wellness
        change(&w)
        next.wellness = w
        commit(next)
    }
    func updateDetails(on date: Date, _ change: (inout DayDetails) -> Void) {
        updateDay(date) { day in
            var details = day.details ?? DayDetails()
            change(&details)
            day.details = details
        }
    }
    func routines(on date: Date, kind: RoutineKind? = nil) -> [Routine] {
        let key = DayKey.string(date)
        let planned = record(on: date).details?.plannedRoutines
        return wellness.routines.filter { routine in
            if let kind, routine.kind != kind { return false }
            let outgoing = wellness.moves.contains { $0.routineID == routine.id && $0.from == key }
            let incoming = wellness.moves.contains { $0.routineID == routine.id && $0.to == key }
            return !outgoing && (incoming || (planned.map { $0.contains(routine.id) } ?? routine.scheduled(on: date)))
        }
    }
    func saveRoutine(_ routine: Routine) {
        reconcileRoutines()
        updateWellness { w in
            if let i = w.routines.firstIndex(where: { $0.id == routine.id }) { w.routines[i] = routine }
            else { w.routines.append(routine) }
        }
        // Recompute today's plan; completed items remain visible.
        let today = Date()
        let done = record(on: today).details?.completedRoutines ?? []
        updateDetails(on: today) { $0.plannedRoutines = wellness.routines.filter { $0.scheduled(on: today) || done.contains($0.id) }.map(\.id) }
    }
    func reconcileRoutines() {
        guard let first = wellness.routines.map(\.createdDay).min(), var date = DayKey.date(first) else { return }
        var next = data
        let today = DayKey.calendar.startOfDay(for: Date())
        var count = 0
        while date <= today && count < 40000 {
            let key = DayKey.string(date)
            var day = next.days[key] ?? DayRecord()
            var details = day.details ?? DayDetails()
            if details.plannedRoutines == nil {
                details.plannedRoutines = wellness.routines.filter { $0.scheduled(on: date) }.map(\.id)
                day.details = details; next.days[key] = day
            }
            date = DayKey.adding(1, to: date); count += 1
        }
        if next != data { commit(next) }
    }
    func toggleRoutine(_ routine: Routine, on date: Date) {
        guard DayKey.string(date) <= DayKey.string(Date()) else { error = "Будущие дни можно планировать, а отмечать — когда они наступят."; return }
        var next = data
        let key = DayKey.string(date)
        var day = record(on: date)
        var details = day.details ?? DayDetails()
        if details.completedRoutines.contains(routine.id) { details.completedRoutines.remove(routine.id) }
        else {
            details.completedRoutines.insert(routine.id)
            var w = wellness
            // Moving/toggling an occurrence never awards a second heart for that occurrence.
            var origin = key
            var visited: Set<String> = []
            while let move = w.moves.first(where: { $0.routineID == routine.id && $0.to == origin }), !visited.contains(origin) {
                visited.insert(origin); origin = move.from
            }
            w.pet.rewardKeys.insert("routine:\(routine.id):\(origin)")
            next.wellness = w
        }
        day.details = details; next.days[key] = day
        commit(next)
    }
    func moveRoutine(_ routine: Routine, from: Date, to: Date) throws {
        let source = DayKey.string(from), destination = DayKey.string(to)
        guard source != destination, destination >= DayKey.string(Date()), routines(on: from).contains(where: { $0.id == routine.id }),
              !(record(on: from).details?.completedRoutines.contains(routine.id) ?? false) else { throw DataError.sameDay }
        guard !routines(on: to).contains(where: { $0.id == routine.id }),
              !wellness.moves.contains(where: { $0.routineID == routine.id && $0.from == destination }) else { throw DataError.moveConflict }
        updateWellness { $0.moves.append(RoutineMove(routineID: routine.id, from: source, to: destination)) }
    }
    func buy(_ item: PetItem) {
        guard !wellness.pet.owned.contains(item.id), wellness.pet.hearts >= item.price else { error = "Пока не хватает сердечек. Плюша рада тебе и без покупок."; return }
        updateWellness { $0.pet.owned.insert(item.id) }
    }
    func equip(_ item: PetItem) {
        guard wellness.pet.owned.contains(item.id) else { return }
        updateWellness {
            switch item.kind {
            case "room": $0.pet.room = item.id
            case "accessory": $0.pet.accessory = $0.pet.accessory == item.id ? nil : item.id
            default: $0.pet.decoration = $0.pet.decoration == item.id ? nil : item.id
            }
        }
    }
    func saveSleep(_ entry: SleepEntry?, on date: Date) {
        updateDetails(on: date) { $0.sleep = entry }
    }
    func addFavorite(_ meal: Meal) {
        guard !wellness.favorites.contains(where: { $0.text == meal.text && $0.photo == meal.photo }) else { return }
        var copy = meal; copy.id = UUID()
        updateWellness { $0.favorites.append(copy) }
    }
    func customizeExercise(_ exercise: Exercise, on date: Date) {
        var session = session(on: date)
        guard let i = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let existing = session.completed[exercise.id.uuidString] ?? []
        guard existing.allSatisfy({ $0 < exercise.sets }) else { error = "Нельзя удалить уже выполненные подходы. Их история сохранена."; return }
        session.exercises[i] = exercise
        updateDay(date) { $0.workout = session }
    }
    func periodReport(ending date: Date, days count: Int) -> String {
        let dates = (-(count - 1)...0).map { DayKey.adding($0, to: date) }
        var result = count > 1 ? "Недельный отчёт для Астраси\n\(DayKey.string(dates[0])) — \(DayKey.string(date))\n\n" : ""
        for day in dates {
            let d = record(on: day).details ?? DayDetails()
            let finished = wellness.routines.filter { d.completedRoutines.contains($0.id) }.map(\.title)
            result += report(on: day) + "\nСон: " + (d.sleepHours.map { String(format: "%.1f ч", $0) } ?? "не записан")
            result += "\nНастроение: " + (d.mood.map { "\($0)/5" } ?? "не записано")
            result += "\nПривычки и уход: " + (finished.isEmpty ? "нет отметок" : finished.joined(separator: ", "))
            for meal in record(on: day).meals {
                if let detail = meal.details { result += "\n\(meal.category): сытость — \(detail.satiety); самочувствие — \(detail.feeling.isEmpty ? "не записано" : detail.feeling)" }
            }
            result += "\n\n"
        }
        return result
    }
}
