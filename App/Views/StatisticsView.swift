import SwiftUI
import Charts

enum WellnessMetric: String, CaseIterable {
    case workouts = "Тренировки", steps = "Шаги", sleep = "Сон", mood = "Настроение"
    var unit: String {
        switch self { case .workouts: return "подходов"; case .steps: return "шагов"; case .sleep: return "часов"; case .mood: return "из 5" }
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var health: HealthService
    @State private var metric: WellnessMetric
    @State private var period = 7
    init(initialMetric: WellnessMetric = .workouts) { _metric = State(initialValue: initialMetric) }
    private var dates: [Date] { (-(period - 1)...0).map { DayKey.calendar.startOfDay(for: DayKey.adding($0, to: store.selectedDate)) } }
    private func value(_ date: Date) -> Double? {
        let day = store.record(on: date)
        switch metric {
        case .workouts: return day.workout.map { Double($0.doneCount) }
        case .steps: return day.steps.map(Double.init)
        case .sleep: return day.details?.sleepHours
        case .mood: return day.details?.mood.map(Double.init)
        }
    }
    private var samples: [Double] { dates.compactMap(value) }
    var body: some View {
        Page {
            DayPicker()
            Picker("Период", selection: $period) { Text("7 дней").tag(7); Text("30 дней").tag(30); Text("90 дней").tag(90) }.pickerStyle(.segmented)
            Picker("Показатель", selection: $metric) { ForEach(WellnessMetric.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            SoftCard(tint: .lavender) {
                Text(metric.rawValue).font(.title2.bold())
                if samples.isEmpty {
                    Text("В этом периоде ещё нет записей. Дни без данных не считаются нулями.").foregroundStyle(.secondary)
                } else {
                    Text(summary).font(.title3.weight(.semibold))
                    Chart {
                        ForEach(dates, id: \.self) { day in
                            if let amount = value(day) {
                                BarMark(x: .value("Дата", day, unit: .day), y: .value(metric.unit, amount))
                                    .foregroundStyle(Color.accent.gradient).cornerRadius(4)
                                    .accessibilityLabel(DayKey.title(day))
                                    .accessibilityValue("\(amount.formatted(.number.precision(.fractionLength(0...1)))) \(metric.unit)")
                            }
                        }
                    }.chartXScale(domain: dates[0]...DayKey.adding(1, to: dates.last!))
                        .chartYAxisLabel(metric.unit).frame(height: 230)
                    Text("Дней с данными: \(samples.count) из \(period). Пустые дни не включены в среднее.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if metric == .workouts {
                let complete = dates.filter { store.record(on: $0).workout?.isComplete == true }.count
                let planned = dates.filter { let s = store.record(on: $0).workout; return s?.exercises.isEmpty == false && s?.movedTo == nil }.count
                SoftCard(tint: .rose) {
                    Text("Завершено занятий: \(complete) из \(planned)").font(.headline)
                    Text("Частично выполненные подходы тоже видны на графике. Можно продолжать в своём темпе.")
                }
            }
            DisclosureGroup("Записи по дням") {
                ForEach(dates.reversed(), id: \.self) { day in
                    HStack {
                        Text(DayKey.title(day))
                        Spacer()
                        Text(value(day).map { $0.formatted(.number.precision(.fractionLength(0...1))) + " " + metric.unit } ?? "Нет записи")
                    }.font(.caption).padding(.vertical, 6)
                }
            }
        }.navigationTitle("Мой ритм в цифрах").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(period)-\(DayKey.string(store.selectedDate))") { await health.sync(store: store, days: period) }
    }
    private var summary: String {
        let total = samples.reduce(0, +)
        if metric == .sleep || metric == .mood { return "В среднем \((total / Double(max(1, samples.count))).formatted(.number.precision(.fractionLength(1)))) \(metric.unit)" }
        return "Всего \(Int(total)) \(metric.unit)"
    }
}
