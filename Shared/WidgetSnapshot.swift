import Foundation

struct WidgetSnapshot: Codable {
    var date = Date()
    var hidden = true
    var plan = ""
    var routines: [String] = []
    var completed = 0
    var petName = "Плюша"
    var accessory: String?
    var decoration: String?
    var room = "lavender"
    static var url: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "NRAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-snapshot.json")
    }
    static func load() -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(Self.self, from: data),
              Calendar.current.isDateInToday(snapshot.date) else { return WidgetSnapshot() }
        return snapshot
    }
}
