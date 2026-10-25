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
    private var observers: [HKObserverQuery] = []
    private weak var journal: JournalStore?
    private var pendingDays: Int?
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
            try await healthStore.requestAuthorization(toShare: [], read: [type, HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!])
            var p = store.data.preferences
            p.healthEnabled = true
            store.setPreferences(p)
            await sync(store: store)
        } catch { message = "Не удалось подключить «Здоровье». Ручной ввод доступен. \(error.localizedDescription)" }
        #else
        message = "Эта сборка использует ручной ввод шагов. Вариант HealthKit доступен отдельно."
        #endif
    }
    func sync(store: JournalStore, days: Int = 7) async {
        #if HEALTHKIT
        guard available, store.data.preferences.healthEnabled else { return }
        if syncing { pendingDays = max(pendingDays ?? 1, days); return }
        syncing = true
        defer {
            syncing = false
            if let requested = pendingDays {
                pendingDays = nil
                Task { await self.sync(store: store, days: requested) }
            }
        }
        journal = store
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        if observers.isEmpty {
          let sampleTypes: [HKSampleType] = [type, HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!]
          for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, _ in
                Task { @MainActor in
                    if let self, let journal = self.journal { await self.sync(store: journal) }
                    completion()
                }
            }
            observers.append(query)
            healthStore.execute(query)
          }
        }
        do {
            // Include the viewed historical week as well as the current week.
            let keys = Set((DayKey.week(ending: Date()) + (-(min(90, max(1, days)) - 1)...0).map { DayKey.adding($0, to: store.selectedDate) }).map(DayKey.string))
            var values: [String: Int] = [:]
            var sleepValues: [String: Double] = [:]
            for key in keys.sorted() {
                guard let day = DayKey.date(key), day <= Date() else { continue }
                if let steps = try await steps(on: day, type: type) { values[key] = steps }
                if let hours = try await sleep(on: day) { sleepValues[key] = hours }
            }
            var next = store.data
            for key in keys {
                var day = next.days[key] ?? DayRecord()
                // Never interpret denied read access as a confirmed zero.
                day.healthSteps = values[key]
                var details = day.details ?? DayDetails()
                details.healthSleepHours = sleepValues[key]; day.details = details
                next.days[key] = day
            }
            if next != store.data { store.commit(next) }
            message = values.isEmpty && sleepValues.isEmpty
                ? "Нет доступных данных. iOS не сообщает, отказано ли в чтении. Проверьте доступ в «Здоровье» или введите шаги вручную."
                : "Шаги и сон обновлены из «Здоровья». Ручная запись, если есть, имеет приоритет."
        } catch { message = "Синхронизация недоступна: \(error.localizedDescription). Можно ввести шаги вручную." }
        #else
        message = "Ручной ввод шагов доступен без разрешений."
        #endif
    }
    #if HEALTHKIT
    private func sleep(on date: Date) async throws -> Double? {
        let end = DayKey.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let start = DayKey.adding(-1, to: end)
        let window = DateInterval(start: start, end: end)
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue]
                let intervals = (samples as? [HKCategorySample] ?? []).filter { asleep.contains($0.value) && $0.endDate > $0.startDate }
                    .map { DateInterval(start: $0.startDate, end: $0.endDate) }
                continuation.resume(returning: SleepMath.hours(intervals: intervals, within: window))
            }
            healthStore.execute(query)
        }
    }
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
