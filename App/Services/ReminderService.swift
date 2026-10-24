import Foundation
import UserNotifications

@MainActor
final class ReminderService: ObservableObject {
    @Published var message = ""
    private let center = UNUserNotificationCenter.current()
    func apply(store: JournalStore, requestPermission: Bool = false) async {
        if requestPermission {
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                    message = "Уведомления выключены. Разрешить их можно в настройках iPhone."
                    return
                }
            } catch { message = error.localizedDescription; return }
        }
        let settings = await center.notificationSettings()
        center.removeAllPendingNotificationRequests()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            message = "Уведомления не разрешены. Дневник работает без них."
            return
        }
        let p = store.data.preferences
        do {
            if p.mealReminders {
                for (i, hour) in p.mealHours.enumerated() {
                    let content = UNMutableNotificationContent()
                    content.title = "Время позаботиться о себе"
                    content.body = "Небольшая пауза для еды — если сейчас удобно."
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: p.mealMinute), repeats: true)
                    try await center.add(UNNotificationRequest(identifier: "meal-\(i)", content: content, trigger: trigger))
                }
            }
            // Stay below iOS's 64 pending-notification limit. Refresh on every foreground entry/edit.
            if p.workoutReminders {
                for offset in 0..<56 {
                    let day = DayKey.adding(offset, to: Date())
                    let session = store.session(on: day)
                    guard !session.exercises.isEmpty, session.movedTo == nil, !session.isComplete, !session.skipped else { continue }
                    var c = DayKey.calendar.dateComponents([.year, .month, .day], from: day)
                    c.hour = p.workoutHour; c.minute = p.workoutMinute
                    guard let fire = DayKey.calendar.date(from: c), fire > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "Ваш нежный ритм"
                    content.body = "\(session.title). Можно начать с одного подхода или выбрать отдых."
                    content.sound = .default
                    try await center.add(UNNotificationRequest(identifier: "workout-\(DayKey.string(day))", content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
                }
            }
            message = "Напоминания обновлены."
        } catch { message = "Не удалось настроить напоминания: \(error.localizedDescription)" }
    }
}
