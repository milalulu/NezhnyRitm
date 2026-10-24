import Foundation

enum DayKey {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 1
        value.timeZone = .current
        return value
    }
    static func string(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              string(date) == key else { return nil }
        return date
    }
    static func adding(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }
    static func week(ending date: Date) -> [Date] { (-6...0).map { adding($0, to: date) } }
    static func title(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: date)
    }
}

struct Exercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var sets: Int
    var repetitions: String
    var technique: String
    var optional = false
}

struct WorkoutPlan: Codable, Identifiable, Equatable {
    var id = UUID()
    var weekday: Int
    var title: String
    var exercises: [Exercise]
    var isWorkout: Bool { !exercises.isEmpty }
}

struct WorkoutSession: Codable, Equatable {
    var title: String
    var exercises: [Exercise]
    var completed: [String: Set<Int>] = [:]
    var skipped = false
    var movedTo: String?
    var movedFrom: String?
    var doneCount: Int { completed.values.reduce(0) { $0 + $1.count } }
    var totalCount: Int { exercises.reduce(0) { $0 + $1.sets } }
    var requiredTotal: Int { exercises.filter { !$0.optional }.reduce(0) { $0 + $1.sets } }
    var requiredDone: Int {
        exercises.filter { !$0.optional }.reduce(0) { $0 + (completed[$1.id.uuidString]?.count ?? 0) }
    }
    var isComplete: Bool { requiredTotal > 0 && requiredDone == requiredTotal && !skipped && movedTo == nil }
    var progress: Double { requiredTotal > 0 ? Double(requiredDone) / Double(requiredTotal) : 0 }
}

struct Meal: Codable, Identifiable, Equatable {
    var id = UUID()
    var category: String
    var text: String
    var photo: Data?
    var createdAt = Date()
}

struct DayRecord: Codable, Equatable {
    var workout: WorkoutSession?
    var meals: [Meal] = []
    var manualSteps: Int?
    var healthSteps: Int?
    var energy = 3
    var wellbeing = ""
    var comment = ""
    var steps: Int? { manualSteps ?? healthSteps }
}

struct Preferences: Codable, Equatable {
    var name = ""
    var theme = "system"
    var workoutReminders = false
    var mealReminders = false
    var workoutHour = 18
    var workoutMinute = 0
    var mealHours = [9, 14, 19]
    var mealMinute = 0
    var healthEnabled = false
}

struct AppData: Codable, Equatable {
    var version = 1
    var startDay = DayKey.string(Date())
    var schedule = SeedProgram.make()
    // Preserve the plan that actually applied on each day, even before a day was opened.
    var days: [String: DayRecord] = [:]
    var preferences = Preferences()

    func validated() throws -> AppData {
        guard version == 1, DayKey.date(startDay) != nil,
              schedule.count == 7, Set(schedule.map(\.weekday)) == Set(1...7),
              Set(schedule.map(\.id)).count == 7,
              ["system", "light", "dark"].contains(preferences.theme),
              (0...23).contains(preferences.workoutHour), (0...59).contains(preferences.workoutMinute),
              preferences.mealHours.count == 3, preferences.mealHours.allSatisfy({ (0...23).contains($0) }),
              (0...59).contains(preferences.mealMinute) else { throw DataError.invalidBackup }
        func validExercises(_ items: [Exercise]) -> Bool {
            items.count <= 50 && Set(items.map(\.id)).count == items.count && items.allSatisfy {
                (1...20).contains($0.sets) && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                $0.name.count <= 200 && $0.technique.count <= 10000 && $0.repetitions.count <= 200
            }
        }
        guard schedule.allSatisfy({ validExercises($0.exercises) && $0.title.count <= 200 }), days.count <= 40000 else { throw DataError.invalidBackup }
        for (key, day) in days {
            guard DayKey.date(key) != nil, (1...5).contains(day.energy),
                  day.manualSteps.map({ (0...200000).contains($0) }) ?? true,
                  day.healthSteps.map({ $0 >= 0 }) ?? true,
                  Set(day.meals.map(\.id)).count == day.meals.count,
                  day.meals.allSatisfy({ ($0.photo?.count ?? 0) <= 3_000_000 && $0.text.count <= 10000 && $0.category.count <= 100 })
            else { throw DataError.invalidBackup }
            if let session = day.workout {
                guard validExercises(session.exercises),
                      session.movedTo.map({ DayKey.date($0) != nil }) ?? true,
                      session.movedFrom.map({ DayKey.date($0) != nil }) ?? true else { throw DataError.invalidBackup }
                for (id, sets) in session.completed {
                    guard let exercise = session.exercises.first(where: { $0.id.uuidString == id }),
                          sets.allSatisfy({ (0..<exercise.sets).contains($0) }) else { throw DataError.invalidBackup }
                }
            }
        }
        return self
    }
}

enum DataError: LocalizedError {
    case invalidBackup, tooLarge, moveConflict, sameDay, startedWorkout
    var errorDescription: String? {
        switch self {
        case .invalidBackup: return "Файл не похож на резервную копию поддерживаемой версии. Данные не изменены."
        case .tooLarge: return "Размер копии превышает 100 МБ. Выберите меньший файл."
        case .moveConflict: return "На выбранный день уже есть тренировка. Выберите свободный день или сначала перенесите её."
        case .sameDay: return "Выберите другой день, начиная с сегодняшнего."
        case .startedWorkout: return "Перенести можно только ещё не начатую тренировку. Выполненные подходы остаются в истории."
        }
    }
}
