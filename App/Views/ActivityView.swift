import SwiftUI
import Charts

struct ActivityView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var health: HealthService
    @State private var manual = ""
    @State private var saved = false
    private var days: [Date] { DayKey.week(ending: store.selectedDate) }
    private var recordedDays: [Date] { days.filter { store.record(on: $0).steps != nil } }
    var body: some View {
        Page {
            DayPicker()
            SoftCard(tint: .sky) {
                Label("Каждый шаг — часть дня", systemImage: "figure.walk").font(.headline)
                Text(store.record(on: store.selectedDate).steps.map(String.init) ?? "Нет данных")
                    .font(.system(size: 42, weight: .light, design: .rounded))
                Text("Без обязательных целей и сравнений").font(.subheadline).foregroundStyle(.secondary)
                if store.record(on: store.selectedDate).manualSteps != nil { Text("Источник: ручная запись").font(.caption) }
                else if store.record(on: store.selectedDate).healthSteps != nil { Text("Источник: Apple Здоровье").font(.caption) }
            }
            SoftCard {
                SectionTitle(title: "Последние 7 дней", symbol: "chart.bar.xaxis")
                if recordedDays.isEmpty {
                    Text("График появится, когда будут записи шагов.").foregroundStyle(.secondary)
                } else {
                    Chart(days, id: \.self) { date in
                        if let steps = store.record(on: date).steps {
                            BarMark(x: .value("День", date, unit: .day), y: .value("Шаги", steps))
                                .foregroundStyle(Color.accent.gradient).cornerRadius(6)
                                .accessibilityLabel(DayKey.title(date)).accessibilityValue("\(steps) шагов")
                        }
                    }.chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 190)
                    Text("Всего по записям: \(days.reduce(0) { $0 + (store.record(on: $1).steps ?? 0) }) · дней с данными: \(recordedDays.count)/7")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            SoftCard(tint: .sky) {
                SectionTitle(title: "Шаги вручную", symbol: "square.and.pencil")
                TextField("Количество шагов", text: $manual).keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("manualSteps")
                Button("Сохранить шаги") {
                    guard let count = Int(manual), (0...200000).contains(count) else { return }
                    store.updateDay(store.selectedDate) { $0.manualSteps = count }
                    saved = store.error == nil
                }.buttonStyle(PrimaryButtonStyle()).disabled(Int(manual).map { !(0...200000).contains($0) } ?? true)
                if saved { Text("Записано").font(.caption).accessibilityIdentifier("stepsSaved") }
                if store.record(on: store.selectedDate).manualSteps != nil {
                    Button("Убрать ручную запись") { store.updateDay(store.selectedDate) { $0.manualSteps = nil }; manual = ""; saved = false }
                }
            }
            SoftCard {
                SectionTitle(title: "Apple Здоровье", symbol: "heart.fill")
                Text(health.buildSupportsHealth ? "Читаем только шаги. Данные остаются на этом iPhone." : "В сборке для SideStore шаги записываются вручную. Для автоматической синхронизации нужна сборка HealthKit и совместимая подпись.").font(.subheadline)
                if health.available {
                    Button(store.data.preferences.healthEnabled ? "Проверить доступ и обновить" : "Подключить «Здоровье»") {
                        Task { await health.connect(to: store) }
                    }.disabled(health.syncing)
                    if store.data.preferences.healthEnabled {
                        Button("Обновить шаги") { Task { await health.sync(store: store) } }.disabled(health.syncing)
                    }
                }
                if health.syncing { ProgressView("Обновляем…") }
                if !health.message.isEmpty { Text(health.message).font(.caption).foregroundStyle(.secondary) }
            }
        }.dismissKeyboardOnScroll()
            .navigationTitle("Шаги").navigationBarTitleDisplayMode(.inline)
            .onAppear { loadManual() }.onChange(of: store.selectedDate) { _ in loadManual() }
    }
    private func loadManual() { manual = store.record(on: store.selectedDate).manualSteps.map(String.init) ?? ""; saved = false }
}

struct WorkoutHistoryView: View {
    @EnvironmentObject private var store: JournalStore
    private var days: [Date] { (-27...0).map { DayKey.adding($0, to: Date()) }.filter { DayKey.string($0) >= store.data.startDay } }
    var body: some View {
        Page {
            SoftCard {
                SectionTitle(title: "Месяц в своём темпе", symbol: "chart.bar")
                Chart(days, id: \.self) { date in
                    let s = store.session(on: date)
                    if !s.exercises.isEmpty && s.movedTo == nil {
                        BarMark(x: .value("День", date, unit: .day), y: .value("Подходы", s.doneCount))
                            .foregroundStyle(Color.accent.gradient).cornerRadius(3)
                    }
                }.frame(height: 180)
                Text("График показывает выполненные подходы, без серии обязательных дней.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.data.days.keys.sorted(by: >), id: \.self) { key in
                if let date = DayKey.date(key), let session = store.data.days[key]?.workout, !session.exercises.isEmpty {
                    NavigationLink {
                        WorkoutView().onAppear { store.selectedDate = date }
                    } label: {
                        SoftCard(tint: .rose) {
                            Text(DayKey.title(date)).font(.caption)
                            Text(session.title).font(.headline)
                            Text(store.status(on: date)).font(.subheadline).foregroundStyle(.secondary)
                            Text("Подходы: \(session.doneCount)/\(session.totalCount)").font(.caption)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.navigationTitle("История движения")
    }
}
