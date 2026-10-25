import Foundation
#if WIDGETS
import WidgetKit
#endif

enum WidgetPublisher {
    static var available: Bool {
        #if WIDGETS
        return WidgetSnapshot.url != nil
        #else
        return false
        #endif
    }
    static func publish(_ data: AppData) {
        #if WIDGETS
        guard let url = WidgetSnapshot.url else { return }
        var snapshot = WidgetSnapshot()
        let w = data.wellnessValue
        if w.shareWithWidgets && !UserDefaults.standard.bool(forKey: "privacyLock") {
            let date = Date(), key = DayKey.string(Date())
            snapshot.hidden = false
            snapshot.plan = data.days[key]?.workout?.title ?? data.schedule.first { $0.weekday == DayKey.calendar.component(.weekday, from: date) }?.title ?? "Твой день"
            let planned = data.days[key]?.details?.plannedRoutines
            snapshot.routines = w.routines.filter { r in
                let outgoing = w.moves.contains { $0.routineID == r.id && $0.from == key }
                let incoming = w.moves.contains { $0.routineID == r.id && $0.to == key }
                return !outgoing && (incoming || (planned.map { $0.contains(r.id) } ?? r.scheduled(on: date)))
            }.map(\.title)
            snapshot.completed = data.days[key]?.details?.completedRoutines.count ?? 0
            snapshot.petName = w.pet.name; snapshot.accessory = w.pet.accessory; snapshot.decoration = w.pet.decoration; snapshot.room = w.pet.room
        }
        do {
            let bytes = try JSONEncoder().encode(snapshot)
            try bytes.write(to: url, options: [.atomic, .completeFileProtection])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Fail closed: remove any older personal snapshot if writing the redacted one fails.
            if snapshot.hidden { try? FileManager.default.removeItem(at: url); WidgetCenter.shared.reloadAllTimelines() }
        }
        #endif
    }
}
