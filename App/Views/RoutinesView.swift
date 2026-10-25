import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    var kind: RoutineKind = .habit
    @State private var editing: Routine?
    @State private var moving: Routine?
    @State private var moveDate = DayKey.adding(1, to: Date())
    @State private var message: String?
    var body: some View {
        Page {
            DayPicker()
            SoftCard(tint: kind == .habit ? .lavender : .rose) {
                SectionTitle(title: kind == .habit ? "Маленькие ритуалы" : "Время для себя", symbol: kind == .habit ? "leaf" : "sparkles")
                Text("Отмечай то, что получилось. Каждый маленький шаг дарит Плюше сердечко. Пропуски ничего не отнимают.").font(.subheadline)
                Button { editing = Routine(title: "", kind: kind) } label: { Label(kind == .habit ? "Добавить привычку" : "Добавить процедуру", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addRoutine")
            }
            HabitCalendar(kind: kind)
            ForEach(store.routines(on: store.selectedDate, kind: kind)) { routine in
                let done = store.record(on: store.selectedDate).details?.completedRoutines.contains(routine.id) ?? false
                SoftCard(tint: done ? .sky : .lavender) {
                    HStack {
                        Button {
                            store.toggleRoutine(routine, on: store.selectedDate)
                            Task { await reminders.apply(store: store) }
                        } label: {
                            Label(routine.title, systemImage: done ? "checkmark.circle.fill" : routine.symbol).font(.headline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityValue(done ? "Выполнено" : "Не отмечено").accessibilityIdentifier("routine-\(routine.id)")
                        Menu {
                            Button("Изменить") { editing = routine }
                            Button("Перенести отметку") { moving = routine; message = nil }
                                .disabled(done)
                            Button("Завершить расписание") {
                                var archived = routine; archived.archivedDay = DayKey.string(Date()); store.saveRoutine(archived)
                                Task { await reminders.apply(store: store) }
                            }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Действия: \(routine.title)")
                    }
                    if !routine.note.isEmpty { Text(routine.note).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            if store.routines(on: store.selectedDate, kind: kind).isEmpty {
                EmptyNote(symbol: "leaf", title: "Свободный день", message: "Здесь можно оставить место для отдыха или добавить свой ритуал.")
            }
            NavigationLink("Все расписания и архив") { RoutineArchiveView(kind: kind) }
            if kind == .habit { NavigationLink("Тренировки и перенос занятий") { WorkoutView() } }
        }.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { RoutineEditor(routine: $0) }
            .sheet(item: $moving) { routine in
                NavigationStack {
                    Form {
                        DatePicker("Перенести на", selection: $moveDate, in: Date()..., displayedComponents: .date)
                        Text("Выберите день без этой привычки. Переносится одна отметка, а не всё расписание.")
                        if let message { Text(message).foregroundStyle(.red) }
                        Button("Перенести") {
                            do {
                                try store.moveRoutine(routine, from: store.selectedDate, to: moveDate)
                                if store.error == nil { moving = nil; store.selectedDate = moveDate; Task { await reminders.apply(store: store) } }
                            } catch { message = error.localizedDescription }
                        }
                    }.navigationTitle("Другой день")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { moving = nil } } }
                }
            }
    }
}

struct HabitCalendar: View {
    @EnvironmentObject private var store: JournalStore
    let kind: RoutineKind
    @State private var month = Date()
    private var first: Date { DayKey.calendar.date(from: DayKey.calendar.dateComponents([.year, .month], from: month))! }
    private var dates: [Date] {
        let offset = DayKey.calendar.component(.weekday, from: first) - 1
        return (0..<42).map { DayKey.adding($0 - offset, to: first) }
    }
    var body: some View {
        SoftCard {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Предыдущий месяц")
                Spacer()
                Text(month, format: .dateTime.month(.wide).year()).font(.headline)
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Следующий месяц")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)) {
                ForEach(Array(["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"].enumerated()), id: \.offset) { _, label in Text(label).font(.caption2).foregroundStyle(.secondary) }
                ForEach(dates, id: \.self) { date in
                    let ids = Set(store.routines(on: date, kind: kind).map(\.id))
                    let done = (store.record(on: date).details?.completedRoutines ?? []).intersection(ids).count
                    Button { store.selectedDate = date } label: {
                        VStack(spacing: 3) {
                            Text("\(DayKey.calendar.component(.day, from: date))").font(.subheadline)
                            Text(ids.isEmpty ? "·" : "\(done)/\(ids.count)").font(.system(size: 9))
                        }.frame(maxWidth: .infinity, minHeight: 44)
                            .background(done > 0 ? Color.lavender.opacity(0.6) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DayKey.string(date) == DayKey.string(store.selectedDate) ? Color.accent : .clear))
                            .opacity(DayKey.calendar.isDate(date, equalTo: month, toGranularity: .month) ? 1 : 0.35)
                    }.buttonStyle(.plain).accessibilityLabel("\(DayKey.title(date)): отмечено \(done) из \(ids.count)")
                }
            }
            Text("Отметки показывают заботу о себе, а не обязательную норму.").font(.caption).foregroundStyle(.secondary)
        }.onAppear { month = store.selectedDate }
    }
    private func shift(_ n: Int) { month = DayKey.calendar.date(byAdding: .month, value: n, to: month)! }
}

struct RoutineEditor: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    @Environment(\.dismiss) private var dismiss
    @State var routine: Routine
    @State private var remind = false
    @State private var hour = 10
    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $routine.title).accessibilityIdentifier("routineTitle")
                Picker("Значок", selection: $routine.symbol) {
                    ForEach(["sparkles", "heart", "leaf", "moon.stars", "figure.walk", "drop", "book", "sun.max"], id: \.self) { Image(systemName: $0).tag($0) }
                }
                Section("Дни недели") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(ScheduleView.weekday(day), isOn: Binding(get: { routine.weekdays.contains(day) }, set: { if $0 { routine.weekdays.insert(day) } else { routine.weekdays.remove(day) } }))
                    }
                }
                Section("Заметка") { TextField("В удобном тебе темпе", text: $routine.note, axis: .vertical).lineLimit(2...5) }
                Section("Необязательное напоминание") {
                    Toggle("Напоминать", isOn: $remind)
                    if remind { Stepper("Час: \(hour)", value: $hour, in: 0...23); Stepper("Минуты: \(routine.reminderMinute)", value: $routine.reminderMinute, in: 0...59) }
                }
            }.navigationTitle(routine.kind == .habit ? "Привычка" : "Процедура")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            routine.reminderHour = remind ? hour : nil
                            store.saveRoutine(routine)
                            Task { await reminders.apply(store: store, requestPermission: remind) }
                            if store.error == nil { dismiss() }
                        }.disabled(routine.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routine.weekdays.isEmpty)
                            .accessibilityIdentifier("saveRoutine")
                    }
                }
        }.onAppear { remind = routine.reminderHour != nil; hour = routine.reminderHour ?? 10 }
    }
}

struct RoutineArchiveView: View {
    @EnvironmentObject private var store: JournalStore
    let kind: RoutineKind
    @State private var editing: Routine?
    var body: some View {
        List {
            ForEach(store.wellness.routines.filter { $0.kind == kind }) { routine in
                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.title).font(.headline)
                    Text(routine.archivedDay == nil ? "Действующее расписание" : "В архиве; история сохранена").font(.caption)
                    if routine.archivedDay == nil { Button("Изменить расписание") { editing = routine } }
                    else {
                        Button("Создать снова") {
                            var copy = routine; copy.id = UUID(); copy.archivedDay = nil; copy.createdDay = DayKey.string(Date()); editing = copy
                        }
                    }
                }.padding(.vertical, 6)
            }
        }.navigationTitle("Мои ритуалы").sheet(item: $editing) { RoutineEditor(routine: $0) }
    }
}
