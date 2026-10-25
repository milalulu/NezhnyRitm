import SwiftUI
import WidgetKit

struct RhythmEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}
struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry { RhythmEntry(date: Date(), snapshot: WidgetSnapshot()) }
    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        completion(RhythmEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        // A dated snapshot never silently becomes tomorrow's plan.
        let entries = [RhythmEntry(date: now, snapshot: WidgetSnapshot.load()), RhythmEntry(date: midnight, snapshot: WidgetSnapshot())]
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}
struct RhythmWidgetView: View {
    let entry: RhythmEntry
    let kind: String
    @Environment(\.widgetFamily) private var family
    private var snapshot: WidgetSnapshot { entry.snapshot }
    var body: some View {
        Group {
            if snapshot.hidden {
                VStack(spacing: 12) { Image(systemName: "sparkles").font(.title); Text("Ритм").font(.headline); Text("Открой дневник").font(.caption) }
            } else if kind == "pet" {
                HStack {
                    CatArt(accessory: snapshot.accessory, animate: false).frame(maxWidth: .infinity)
                    if family == .systemMedium {
                        VStack(alignment: .leading, spacing: 12) { Text(snapshot.petName).font(.title2.bold()); Text("Рада тебе каждый день").font(.caption); if let decoration = snapshot.decoration { Image(systemName: decoration == "plant" ? "leaf.fill" : "star.fill") } }
                    }
                }.accessibilityLabel("Котик \(snapshot.petName)")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(kind == "habits" ? "Маленькие ритуалы" : "Сегодня", systemImage: kind == "habits" ? "leaf" : "sun.max").font(.caption.weight(.semibold))
                    if kind == "plans" { Text(snapshot.plan).font(.headline).lineLimit(2) }
                    else { Text("Отметок: \(snapshot.completed)").font(.headline) }
                    ForEach(Array(snapshot.routines.prefix(family == .systemSmall ? 2 : 3).enumerated()), id: \.offset) { _, title in Text("· " + title).font(.caption).lineLimit(1) }
                    Spacer(minLength: 0)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(16)
            .rhythmWidgetBackground(snapshot.room == "sky" ? Color.sky : snapshot.room == "rose" ? Color.rose : Color.lavender)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .privacySensitive()
    }
}
extension View {
    @ViewBuilder func rhythmWidgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) { self.containerBackground(for: .widget) { color.opacity(0.24) } }
        else { self.background(color.opacity(0.24)) }
    }
}
struct RhythmWidget: Widget {
    let kind: String
    let title: String
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RhythmProvider()) { RhythmWidgetView(entry: $0, kind: kind) }
            .configurationDisplayName(title).description("Немного заботы в твоём ритме. Данные включаются в настройках приватности.")
            .supportedFamilies([.systemSmall, .systemMedium])

    }
}
@main
struct RhythmWidgets: WidgetBundle {
    var body: some Widget {
        RhythmWidget(kind: "plans", title: "Сегодняшние планы")
        RhythmWidget(kind: "habits", title: "Привычки")
        RhythmWidget(kind: "pet", title: "Плюша рядом")
    }
}
