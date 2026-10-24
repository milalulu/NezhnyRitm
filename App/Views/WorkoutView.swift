import SwiftUI
import UserNotifications

struct WorkoutView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    @State private var showMove = false
    @State private var moveDate = DayKey.adding(1, to: Date())
    @State private var moveError: String?
    private var session: WorkoutSession { store.session(on: store.selectedDate) }
    var body: some View {
        Page {
            DayPicker()
            SoftCard(tint: .rose) {
                Text(session.title).font(.largeTitle.bold())
                Text(store.status(on: store.selectedDate)).foregroundStyle(.secondary)
                if !session.exercises.isEmpty && session.movedTo == nil {
                    ProgressView(value: session.progress)
                    Text("\(session.requiredDone) / \(session.requiredTotal) основных подходов").font(.caption)
                }
            }
            if session.exercises.isEmpty {
                EmptyNote(symbol: "leaf", title: "День без спешки", message: "Можно отдохнуть или выбрать приятную лёгкую активность. Ничего не нужно наверстывать.")
            } else if session.movedTo == nil {
                Text("Двигайся плавно, дыши свободно. Выбирай комфортную амплитуду; при боли остановись.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(session.exercises) { exercise in
                    ExerciseCard(exercise: exercise, session: session, date: store.selectedDate)
                }
                RestTimerView()
                Button {
                    store.toggleSkip(on: store.selectedDate)
                    Task { await reminders.apply(store: store) }
                } label: { Label(session.skipped ? "Вернуться к занятию" : "Сегодня выбираю отдых", systemImage: "leaf") }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(session.isComplete)
                if session.doneCount == 0 {
                    Button { showMove = true } label: { Label("Перенести тренировку", systemImage: "calendar.badge.clock") }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            NavigationLink { ScheduleView() } label: { Label("Моё расписание", systemImage: "calendar") }.buttonStyle(PrimaryButtonStyle())
            NavigationLink { WorkoutHistoryView() } label: { Label("История и прогресс", systemImage: "chart.bar") }.padding(.vertical, 8)
        }
        .navigationTitle("Движение").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMove) {
            NavigationStack {
                Form {
                    DatePicker("Новая дата", selection: $moveDate, in: Date()..., displayedComponents: .date)
                    Text("Подойдёт день отдыха или восстановления. Записи питания и самочувствия останутся на своих датах.")
                    if let moveError { Text(moveError).foregroundStyle(.red) }
                    Button("Перенести") {
                        do {
                            try store.moveWorkout(from: store.selectedDate, to: moveDate)
                            if store.error == nil {
                                showMove = false; store.selectedDate = moveDate
                                Task { await reminders.apply(store: store) }
                            }
                        } catch { moveError = error.localizedDescription }
                    }
                }.navigationTitle("Выбрать другой день")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { showMove = false } } }
            }
        }
    }
}

struct ExerciseCard: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let exercise: Exercise
    let session: WorkoutSession
    let date: Date
    var body: some View {
        SoftCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name).font(.headline)
                    Text("\(exercise.sets) × \(exercise.repetitions)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if exercise.optional { Image(systemName: "sparkles").accessibilityLabel("Необязательно") }
            }
            if exercise.optional { Text("Если есть резинка · по желанию").font(.caption).foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 10) {
                ForEach(0..<exercise.sets, id: \.self) { index in
                    let done = session.completed[exercise.id.uuidString]?.contains(index) ?? false
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { store.toggleSet(exercise, index: index, on: date) }
                        if store.session(on: date).isComplete != session.isComplete { Task { await reminders.apply(store: store) } }
                    } label: {
                        Label("\(index + 1)", systemImage: done ? "checkmark.circle.fill" : "circle")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                            .background(done ? Color.lavender.opacity(0.55) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(exercise.name), подход \(index + 1), \(done ? "выполнен" : "не выполнен")")
                        .accessibilityIdentifier("set-\(exercise.id)-\(index)")
                }
            }
            DisclosureGroup("Техника упражнения") { Text(exercise.technique).font(.subheadline).padding(.top, 8) }
        }
    }
}

struct RestTimerView: View {
    @AppStorage("restEnd") private var end: Double = 0
    @State private var duration = 60
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    private var remaining: Int { max(0, Int(ceil(end - now.timeIntervalSince1970))) }
    var body: some View {
        SoftCard(tint: .sky) {
            SectionTitle(title: "Пауза между подходами", symbol: "timer")
            if remaining > 0 {
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60)).font(.system(size: 44, weight: .light, design: .rounded)).monospacedDigit()
                Button("Завершить паузу") { end = 0; UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"]) }
            } else {
                Picker("Длительность отдыха", selection: $duration) {
                    Text("30 с").tag(30); Text("60 с").tag(60); Text("90 с").tag(90); Text("120 с").tag(120)
                }.pickerStyle(.segmented)
                Button(end > 0 ? "Пауза завершена · ещё раз" : "Начать паузу") {
                    now = Date(); end = now.timeIntervalSince1970 + Double(duration)
                    let seconds = duration
                    Task {
                        let center = UNUserNotificationCenter.current()
                        let settings = await center.notificationSettings()
                        if settings.authorizationStatus == .authorized {
                            let content = UNMutableNotificationContent()
                            content.title = "Пауза завершена"; content.body = "Продолжай, когда будешь готова."; content.sound = .default
                            try? await center.add(UNNotificationRequest(identifier: "rest-timer", content: content,
                                trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)))
                        }
                    }
                }.frame(maxWidth: .infinity, minHeight: 44)
            }
        }.onReceive(timer) { now = $0 }
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: JournalStore
    var body: some View {
        List {
            Section {
                Text("Нагрузка меняется только по твоему желанию. Изменения применятся к будущим занятиям и к ещё не начатому занятию сегодня.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.data.schedule.sorted { $0.weekday < $1.weekday }) { plan in
                NavigationLink { PlanEditor(plan: plan) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Self.weekday(plan.weekday)).font(.caption).foregroundStyle(.secondary)
                        Text(plan.title).font(.headline)
                        Text(plan.exercises.isEmpty ? "Без обязательных упражнений" : "Упражнений: \(plan.exercises.count)").font(.caption)
                    }.padding(.vertical, 6)
                }
            }
        }.navigationTitle("Расписание")
    }
    static func weekday(_ day: Int) -> String {
        ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"][day - 1]
    }
}

struct PlanEditor: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    @Environment(\.dismiss) private var dismiss
    @State var plan: WorkoutPlan
    @State private var exercise: Exercise?
    var body: some View {
        List {
            Section("Название дня") { TextField("Название", text: $plan.title) }
            Section("Упражнения · смахни для удаления") {
                ForEach(plan.exercises) { item in
                    Button { exercise = item } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name).foregroundStyle(.primary)
                            Text("\(item.sets) × \(item.repetitions)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { plan.exercises.remove(atOffsets: $0) }.onMove { plan.exercises.move(fromOffsets: $0, toOffset: $1) }
                Button { exercise = Exercise(name: "", sets: 2, repetitions: "10", technique: "") } label: { Label("Своё упражнение", systemImage: "plus") }
            }
        }.navigationTitle(ScheduleView.weekday(plan.weekday))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        store.savePlan(plan)
                        Task { await reminders.apply(store: store) }
                        if store.error == nil { dismiss() }
                    }.disabled(plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $exercise) { item in
                ExerciseEditor(exercise: item) { edited in
                    if let index = plan.exercises.firstIndex(where: { $0.id == edited.id }) { plan.exercises[index] = edited }
                    else { plan.exercises.append(edited) }
                }
            }
    }
}

struct ExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var exercise: Exercise
    let save: (Exercise) -> Void
    var body: some View {
        NavigationStack {
            Form {
                TextField("Название упражнения", text: $exercise.name)
                Stepper("Подходы: \(exercise.sets)", value: $exercise.sets, in: 1...20)
                TextField("Повторения или время", text: $exercise.repetitions)
                Section("Техника") { TextEditor(text: $exercise.technique).frame(minHeight: 130) }
                Toggle("Необязательное упражнение", isOn: $exercise.optional)
            }.navigationTitle("Упражнение")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { save(exercise); dismiss() }
                            .disabled(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercise.repetitions.isEmpty)
                    }
                }
        }
    }
}
