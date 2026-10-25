import SwiftUI
import Charts

struct SleepView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var health: HealthService
    @State private var editing = false
    private var detail: DayDetails { store.record(on: store.selectedDate).details ?? DayDetails() }
    var body: some View {
        Page {
            DayPicker()
            SoftCard(tint: .lavender) {
                SectionTitle(title: "Место для восстановления", symbol: "moon.stars")
                Text(detail.sleepHours.map { String(format: "%.1f ч", $0) } ?? "Сон ещё не записан").font(.largeTitle.weight(.light))
                Text(detail.sleep != nil ? "Ручная запись · дата пробуждения" : "Данные за сутки до полудня выбранного дня").font(.caption).foregroundStyle(.secondary)
                if let quality = detail.sleep?.quality { Text("Ощущение отдыха: \(quality) из 5").font(.subheadline) }
                if let note = detail.sleep?.note, !note.isEmpty { Text(note) }
                Button { editing = true } label: { Label("Записать сон", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addSleep")
                if detail.sleep != nil { Button("Удалить ручную запись", role: .destructive) { store.saveSleep(nil, on: store.selectedDate) } }
            }
            SoftCard(tint: .sky) {
                SectionTitle(title: "Мягкая пауза", symbol: "leaf")
                Text((store.record(on: store.selectedDate).energy ?? 3) <= 2
                     ? "Сегодня можно выбрать облегчённое занятие или отдых. Отметки не нужно наверстывать."
                     : "Спокойный вечерний ритуал и удобное постоянное время сна могут помочь настроиться на отдых. Выбери то, что подходит тебе.")
                Text("Это общие идеи для отдыха, а не оценка качества сна или медицинское заключение.").font(.caption).foregroundStyle(.secondary)
                Link("Об отдыхе и вечернем ритуале · NHS", destination: URL(string: "https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/how-to-fall-asleep-faster-and-sleep-better/")!).font(.caption)
            }
            NavigationLink { StatisticsView(initialMetric: .sleep) } label: { Label("График сна и восстановления", systemImage: "chart.bar") }
            SoftCard {
                SectionTitle(title: "Apple Здоровье", symbol: "heart")
                Text(health.buildSupportsHealth ? "Читаем только шаги и сон с твоего разрешения. Пересекающиеся интервалы сна не считаются дважды. Ручная запись имеет приоритет." : "Ручной дневник сна работает полностью офлайн. Автоматическое чтение доступно в варианте HealthKit с подходящей подписью.")
                    .font(.subheadline)
                if health.available { Button("Подключить или обновить доступ") { Task { await health.connect(to: store) } }.disabled(health.syncing) }
                if !health.message.isEmpty { Text(health.message).font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Сон и отдых").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) { SleepEditor(date: store.selectedDate) }
    }
}

struct SleepEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var start = Date()
    @State private var end = Date()
    @State private var quality = 0
    @State private var note = ""
    private var hours: Double { end.timeIntervalSince(start) / 3600 }
    var body: some View {
        NavigationStack {
            Form {
                Text("Запись относится к выбранному дню пробуждения. Дневной сон тоже можно записать.").font(.footnote)
                DatePicker("Заснула", selection: $start)
                DatePicker("Проснулась", selection: $end, in: DayKey.calendar.startOfDay(for: date)...DayKey.adding(1, to: DayKey.calendar.startOfDay(for: date)).addingTimeInterval(-1))
                Text(String(format: "Продолжительность: %.1f ч", max(0, hours)))
                Picker("Как ощущается отдых", selection: $quality) {
                    Text("Не отмечено").tag(0)
                    ForEach(1...5, id: \.self) { Text("\($0) из 5").tag($0) }
                }
                TextField("Заметка", text: $note, axis: .vertical).lineLimit(3...6)
            }.navigationTitle("Мой сон").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            store.saveSleep(SleepEntry(start: start, end: end, quality: quality == 0 ? nil : quality, note: note), on: date)
                            if store.error == nil { dismiss() }
                        }.disabled(hours <= 0 || hours > 24).accessibilityIdentifier("saveSleep")
                    }
                }
        }.onAppear {
            if let old = store.record(on: date).details?.sleep { start = old.start; end = old.end; quality = old.quality ?? 0; note = old.note }
            else {
                end = DayKey.calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
                start = end.addingTimeInterval(-8 * 3600)
            }
        }
    }
}
