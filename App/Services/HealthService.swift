import Foundation
import Combine
#if HEALTHKIT
import HealthKit
#endif

@MainActor
final class HealthService: ObservableObject {
    @Published var message = ""
    @Published var syncing = false
    #if HEALTHKIT
    private let healthStore = HKHealthStore()
    private var observer: HKObserverQuery?
    private weak var journal: JournalStore?
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    #else
    var available: Bool { false }
    #endif
    var buildSupportsHealth: Bool {
        #if HEALTHKIT
        return true
        #else
        return false
        #endif
    }
    func connect(to store: JournalStore) async {
        #if HEALTHKIT
        guard available else { message = "На этом устройстве «Здоровье» недоступно. Можно записать шаги вручную."; return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [type])
            var p = store.data.preferences
            p.healthEnabled = true
            store.setPreferences(p)
            await sync(store: store)
        } catch { message = "Не удалось подключить «Здоровье». Ручной ввод доступен. \(error.localizedDescription)" }
        #else
        message = "Эта сборка использует ручной ввод шагов. Вариант HealthKit доступен отдельно."
        #endif
    }
    func sync(store: JournalStore) async {
        #if HEALTHKIT
        guard available, store.data.preferences.healthEnabled, !syncing else { return }
        syncing = true
        defer { syncing = false }
        journal = store
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        if observer == nil {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor in
                    if let self, let journal = self.journal { await self.sync(store: journal) }
                    completion()
                }
            }
            observer = query
            healthStore.execute(query)
        }
        do {
            // Include the viewed historical week as well as the current week.
            let keys = Set((DayKey.week(ending: Date()) + DayKey.week(ending: store.selectedDate)).map(DayKey.string))
            var values: [String: Int] = [:]
            for key in keys.sorted() {
                guard let day = DayKey.date(key), day <= Date() else { continue }
                if let steps = try await steps(on: day, type: type) { values[key] = steps }
            }
            var next = store.data
            for key in keys {
                var day = next.days[key] ?? DayRecord()
                // Never interpret denied read access as a confirmed zero.
                day.healthSteps = values[key]
                next.days[key] = day
            }
            if next != store.data { store.commit(next) }
            message = values.isEmpty
                ? "Нет доступных данных. iOS не сообщает, отказано ли в чтении. Проверьте доступ в «Здоровье» или введите шаги вручную."
                : "Шаги обновлены из «Здоровья». Ручная запись, если есть, имеет приоритет."
        } catch { message = "Синхронизация недоступна: \(error.localizedDescription). Можно ввести шаги вручную." }
        #else
        message = "Ручной ввод шагов доступен без разрешений."
        #endif
    }
    #if HEALTHKIT
    private func steps(on date: Date, type: HKQuantityType) async throws -> Int? {
        let start = DayKey.calendar.startOfDay(for: date)
        let end = DayKey.adding(1, to: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity().map { Int($0.doubleValue(for: .count())) }) }
            }
            healthStore.execute(query)
        }
    }
    #endif
}
