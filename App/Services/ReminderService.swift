import Foundation
import Combine
import UserNotifications

@MainActor
final class ReminderService: ObservableObject {
    @Published var message = ""
    private let center = UNUserNotificationCenter.current()
    private var generation = UUID()
    func apply(store: JournalStore, requestPermission: Bool = false) async {
        let token = UUID(); generation = token
        if requestPermission {
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                    message = "Уведомления выключены. Разрешить их можно в настройках iPhone."; return
                }
            } catch { message = error.localizedDescription; return }
        }
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        guard token == generation else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("meal-") || $0.hasPrefix("workout-") || $0.hasPrefix("routine-") })
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            message = "Уведомления не разрешены. Дневник работает без них."; return
        }
        let p = store.data.preferences
        let hidden = store.wellness.privateNotifications
        func content(_ title: String, _ body: String) -> UNMutableNotificationContent {
            let c = UNMutableNotificationContent()
            c.title = hidden ? "Ритм" : title; c.body = hidden ? "Твоё напоминание. Открой приложение, когда будет удобно." : body
            c.sound = .default; return c
        }
        do {
            if p.mealReminders {
                for (i, hour) in p.mealHours.enumerated() {
                    guard token == generation else { return }
                    let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: p.mealMinute), repeats: true)
                    try await center.add(UNNotificationRequest(identifier: "meal-\(i)", content: content("Время позаботиться о себе", "Небольшая пауза для еды — если сейчас удобно."), trigger: trigger))
                }
            }
            var dated: [(Date, UNNotificationRequest)] = []
            func append(_ day: Date, _ hour: Int, _ minute: Int, _ id: String, _ title: String, _ body: String) {
                var c = DayKey.calendar.dateComponents([.year, .month, .day], from: day)
                c.hour = hour; c.minute = minute
                guard let fire = DayKey.calendar.date(from: c), fire > Date() else { return }
                dated.append((fire, UNNotificationRequest(identifier: id, content: content(title, body), trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false))))
            }
            for offset in 0..<56 {
                let day = DayKey.adding(offset, to: Date()), key = DayKey.string(day)
                let session = store.session(on: day)
                if p.workoutReminders && !session.exercises.isEmpty && session.movedTo == nil && !session.isComplete && !session.skipped {
                    append(day, p.workoutHour, p.workoutMinute, "workout-\(key)", "Твой нежный ритм", "\(session.title). Можно начать с одного подхода или выбрать отдых.")
                }
                let completed = store.record(on: day).details?.completedRoutines ?? []
                for routine in store.routines(on: day) {
                    if let hour = routine.reminderHour, !completed.contains(routine.id) {
                        append(day, hour, routine.reminderMinute, "routine-\(routine.id)-\(key)", "Немного заботы", routine.title)
                    }
                }
            }
            // 59 dated + 3 meal + 1 rest = at most 63, below iOS's 64 request limit.
            for (_, request) in dated.sorted(by: { $0.0 < $1.0 }).prefix(59) {
                guard token == generation else { return }
                try await center.add(request)
            }
            message = "Ближайшие напоминания обновлены. Открывай дневник, чтобы продлить расписание."
        } catch { message = "Не удалось настроить напоминания: \(error.localizedDescription)" }
    }
}
