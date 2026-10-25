import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: JournalStore
    @State private var showWellbeing = false
    private var day: DayRecord { store.record(on: store.selectedDate) }
    private var session: WorkoutSession { store.session(on: store.selectedDate) }
    var body: some View {
        Page {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("МАЛЕНЬКИЕ ШАГИ К СЕБЕ").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                    Text(store.data.preferences.name.isEmpty ? "Привет, это твой ритм" : "Привет, \(store.data.preferences.name)")
                        .font(.largeTitle.weight(.bold)).accessibilityIdentifier("greeting")
                    Text(DayKey.title(Date())).font(.subheadline).foregroundStyle(.secondary)
                }
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(Color.accent).padding(.top, 24)
            }
            DayPicker()
            SoftCard(tint: .rose) {
                Text("ДВИЖЕНИЕ И ЗАБОТА").font(.caption.weight(.semibold)).tracking(1.5)
                Text(session.title).font(.title2.weight(.bold))
                if store.status(on: store.selectedDate) != session.title {
                    Text(store.status(on: store.selectedDate)).font(.subheadline).foregroundStyle(.secondary)
                }
                if !session.exercises.isEmpty && session.movedTo == nil {
                    ProgressView(value: session.progress).tint(.accent)
                    Text("\(session.requiredDone) из \(session.requiredTotal) основных подходов").font(.caption)
                    NavigationLink { WorkoutView() } label: {
                        Label("К тренировке", systemImage: "arrow.right")
                    }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("Отдых тоже часть ритма. Можно выбрать прогулку, мягкую разминку или просто побыть в покое.")
                        .font(.subheadline)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                SoftCard(tint: .sky) {
                    Image(systemName: "figure.walk").font(.title2)
                    Text(day.steps.map { $0.formatted(.number.locale(Locale(identifier: "ru_RU"))) } ?? "—").font(.title2.bold())
                    Text("шагов · без нормы").font(.caption).foregroundStyle(.secondary)
                }
                SoftCard(tint: .lavender) {
                    Image(systemName: "fork.knife").font(.title2)
                    Text("\(day.meals.count)").font(.title2.bold())
                    Text("записей питания").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { showWellbeing = true } label: {
                SoftCard(tint: .sky) {
                    HStack {
                        Label("Как ты себя чувствуешь?", systemImage: "heart").font(.headline)
                        Spacer(); Image(systemName: "chevron.right")
                    }
                    Text(day.wellbeing.isEmpty ? "Запиши энергию и пару слов о себе" : day.wellbeing)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
            }.buttonStyle(.plain)
            NavigationLink { RoutinesView() } label: {
                SoftCard(tint: .lavender) {
                    Label("Маленькие привычки", systemImage: "checkmark.circle").font(.headline)
                    Text("Сон, прогулки и забота о себе — в своём ритме").font(.subheadline)
                }
            }.buttonStyle(.plain)
            HStack {
                NavigationLink { SleepView() } label: { Label("Сон и отдых", systemImage: "moon.stars") }
                Spacer()
                NavigationLink { PetView() } label: { Label(store.wellness.pet.name, systemImage: "pawprint") }
            }.padding(.vertical, 8)
            CalendarCard()
            NavigationLink { ReportView() } label: {
                Label("Отправить отчёт", systemImage: "square.and.arrow.up")
            }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("openReport")
            Text("Здесь нет штрафов и гонки. Достаточно быть на своей стороне.")
                .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
        .navigationTitle("Сегодня").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWellbeing) { WellbeingEditor(date: store.selectedDate) }
    }
}

struct CalendarCard: View {
    @EnvironmentObject private var store: JournalStore
    @State private var month = Date()
    private var first: Date { DayKey.calendar.date(from: DayKey.calendar.dateComponents([.year, .month], from: month))! }
    private var dates: [Date] {
        let offset = DayKey.calendar.component(.weekday, from: first) - 1
        return (0..<42).map { DayKey.adding($0 - offset, to: first) }
    }
    private func color(_ date: Date) -> Color {
        let s = store.session(on: date)
        if s.isComplete { return .accent }
        if s.doneCount > 0 { return .orange }
        if !s.exercises.isEmpty && s.movedTo == nil && DayKey.string(date) >= store.data.startDay && date < DayKey.calendar.startOfDay(for: Date()) { return .secondary.opacity(0.5) }
        return .clear
    }
    var body: some View {
        SoftCard {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Предыдущий месяц")
                Spacer()
                Text(month, format: .dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))).font(.headline)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Следующий месяц")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(Array(["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"].enumerated()), id: \.offset) { _, name in
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(dates, id: \.self) { date in
                    Button { store.selectedDate = date } label: {
                        VStack(spacing: 3) {
                            Text("\(DayKey.calendar.component(.day, from: date))").font(.subheadline)
                            Circle().fill(color(date)).frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(DayKey.string(date) == DayKey.string(store.selectedDate) ? Color.lavender.opacity(0.5) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .opacity(DayKey.calendar.isDate(date, equalTo: month, toGranularity: .month) ? 1 : 0.35)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(DayKey.title(date)), \(store.status(on: date))")
                }
            }
            Text("● Лиловый — выполнено · оранжевый — часть подходов · серый — пропущено")
                .font(.caption2).foregroundStyle(.secondary)
        }.onAppear { month = store.selectedDate }
    }
    private func shift(_ n: Int) { month = DayKey.calendar.date(byAdding: .month, value: n, to: month)! }
}

struct WellbeingEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var energy = 3
    @State private var mood = 0
    @State private var wellbeing = ""
    @State private var comment = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Энергия: \(energy) из 5") {
                    Picker("Энергия", selection: $energy) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented)
                    Text("1 — хочется отдыха, 5 — много сил. Любое состояние нормально.").font(.footnote)
                }
                Picker("Настроение", selection: $mood) {
                    Text("Не отмечено").tag(0)
                    ForEach(1...5, id: \.self) { Text("\($0) из 5").tag($0) }
                }
                Section("Самочувствие") { TextField("Как чувствует себя тело?", text: $wellbeing, axis: .vertical).lineLimit(3...6) }
                Section("Личный комментарий") { TextField("Что хочется рассказать?", text: $comment, axis: .vertical).lineLimit(3...6) }
            }.navigationTitle("На связи с собой").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            store.updateDay(date) {
                                $0.energy = energy; $0.wellbeing = wellbeing; $0.comment = comment
                                var d = $0.details ?? DayDetails(); d.mood = mood == 0 ? nil : mood; $0.details = d
                            }
                            if store.error == nil { dismiss() }
                        }
                    }
                }
        }.onAppear {
            let day = store.record(on: date)
            mood = day.details?.mood ?? 0
            energy = day.energy ?? 3; wellbeing = day.wellbeing; comment = day.comment
        }
    }
}
