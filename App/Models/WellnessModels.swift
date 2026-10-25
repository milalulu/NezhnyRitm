import Foundation

enum RoutineKind: String, Codable, CaseIterable { case habit, care
    var title: String { self == .habit ? "Привычки" : "Уход за собой" }
}
struct Routine: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var symbol = "sparkles"
    var kind: RoutineKind = .habit
    var weekdays: Set<Int> = Set(1...7)
    var note = ""
    var createdDay = DayKey.string(Date())
    var archivedDay: String?
    var reminderHour: Int?
    var reminderMinute = 0
    func scheduled(on date: Date) -> Bool {
        let key = DayKey.string(date)
        return key >= createdDay && (archivedDay.map { key < $0 } ?? true) && weekdays.contains(DayKey.calendar.component(.weekday, from: date))
    }
    static var initial: [Routine] {
        [Routine(title: "Время для сна", symbol: "moon.stars"), Routine(title: "Прогулка", symbol: "figure.walk"),
         Routine(title: "Маленькая забота о себе", symbol: "heart", kind: .care),
         Routine(title: "Движение в своём темпе", symbol: "figure.mind.and.body", weekdays: [1, 3, 5])]
    }
}
struct RoutineMove: Codable, Identifiable, Equatable {
    var id = UUID()
    var routineID: UUID
    var from: String
    var to: String
}
struct SleepEntry: Codable, Equatable {
    var start: Date
    var end: Date
    var quality: Int?
    var note = ""
    var hours: Double { end.timeIntervalSince(start) / 3600 }
}
struct DayDetails: Codable, Equatable {
    var completedRoutines: Set<UUID> = []
    var plannedRoutines: [UUID]?
    var sleep: SleepEntry?
    var healthSleepHours: Double?
    var mood: Int?
    var sleepHours: Double? { sleep?.hours ?? healthSleepHours }
}
struct MealDetails: Codable, Equatable {
    var satiety: String = "Не отмечена"
    var feeling = ""
}
struct PetItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let price: Int
    let kind: String
    static let catalog = [
        PetItem(id: "bow", title: "Розовый бантик", symbol: "gift", price: 3, kind: "accessory"),
        PetItem(id: "crown", title: "Корона облачка", symbol: "crown", price: 7, kind: "accessory"),
        PetItem(id: "plant", title: "Зелёный друг", symbol: "leaf", price: 4, kind: "decoration"),
        PetItem(id: "stars", title: "Гирлянда звёзд", symbol: "star", price: 6, kind: "decoration"),
        PetItem(id: "sky", title: "Небесная комната", symbol: "cloud", price: 5, kind: "room"),
        PetItem(id: "rose", title: "Розовая комната", symbol: "heart", price: 5, kind: "room")]
}
struct PetState: Codable, Equatable {
    var name = "Плюша"
    var rewardKeys: Set<String> = []
    var owned: Set<String> = []
    var accessory: String?
    var decoration: String?
    var room = "lavender"
    var hearts: Int { rewardKeys.count - PetItem.catalog.filter { owned.contains($0.id) }.reduce(0) { $0 + $1.price } }
}
struct WellnessData: Codable, Equatable {
    var routines = Routine.initial
    var moves: [RoutineMove] = []
    var favorites: [Meal] = []
    var pet = PetState()
    var privateNotifications = true
    var shareWithWidgets = false
}

extension AppData {
    var wellnessValue: WellnessData { wellness ?? WellnessData() }
    func migrated() throws -> AppData {
        _ = try validated()
        var copy = self
        copy.version = 2
        if copy.wellness == nil { copy.wellness = WellnessData() }
        return copy
    }
    func validateWellness() throws {
        func validRating(_ value: Int?) -> Bool { value.map { (1...5).contains($0) } ?? true }
        for day in days.values {
            if let d = day.details {
                guard validRating(d.mood), d.healthSleepHours.map({ $0.isFinite && (0...24).contains($0) }) ?? true else { throw DataError.invalidBackup }
                if let s = d.sleep {
                    guard s.hours.isFinite, s.hours > 0, s.hours <= 24, validRating(s.quality), s.note.count <= 10000 else { throw DataError.invalidBackup }
                }
            }
            guard day.meals.allSatisfy({ ($0.details?.feeling.count ?? 0) <= 10000 }) else { throw DataError.invalidBackup }
        }
        guard let w = wellness else { return }
        let ids = Set(w.routines.map(\.id))
        guard w.routines.count <= 200, ids.count == w.routines.count,
              w.moves.count <= 40000, Set(w.moves.map(\.id)).count == w.moves.count,
              w.routines.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 200 &&
                  $0.weekdays.isSubset(of: Set(1...7)) && !$0.weekdays.isEmpty && DayKey.date($0.createdDay) != nil &&
                  ($0.archivedDay.map { DayKey.date($0) != nil } ?? true) &&
                  ($0.reminderHour.map { (0...23).contains($0) } ?? true) && (0...59).contains($0.reminderMinute) }),
              w.moves.allSatisfy({ ids.contains($0.routineID) && DayKey.date($0.from) != nil && DayKey.date($0.to) != nil && $0.from != $0.to }),
              Set(w.favorites.map(\.id)).count == w.favorites.count, w.favorites.count <= 500,
              w.favorites.allSatisfy({ ($0.photo?.count ?? 0) <= 3_000_000 && $0.text.count <= 10000 }),
              w.pet.name.count <= 60, w.pet.hearts >= 0,
              w.pet.owned.isSubset(of: Set(PetItem.catalog.map(\.id))),
              w.pet.accessory.map({ w.pet.owned.contains($0) }) ?? true,
              w.pet.decoration.map({ w.pet.owned.contains($0) }) ?? true,
              w.pet.room == "lavender" || w.pet.owned.contains(w.pet.room) else { throw DataError.invalidBackup }
        for day in days.values {
            guard (day.details?.completedRoutines ?? []).isSubset(of: ids),
                  Set(day.details?.plannedRoutines ?? []).isSubset(of: ids) else { throw DataError.invalidBackup }
        }
    }
}

// Union overlapping samples, so multiple watches/apps don't count the same sleep twice.
enum SleepMath {
    static func hours(intervals: [DateInterval], within window: DateInterval) -> Double? {
        let clipped = intervals.compactMap { $0.intersection(with: window) }.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = clipped.first else { return nil }
        var total: TimeInterval = 0
        for next in clipped.dropFirst() {
            if next.start <= current.end { current = DateInterval(start: current.start, end: max(current.end, next.end)) }
            else { total += current.duration; current = next }
        }
        return (total + current.duration) / 3600
    }
}
