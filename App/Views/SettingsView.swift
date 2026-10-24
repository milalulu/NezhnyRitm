import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {
    var body: some View {
        Page {
            SoftCard(tint: .lavender) {
                Image(systemName: "heart.circle").font(.system(size: 52, weight: .ultraLight))
                Text("На своей стороне").font(.largeTitle.bold())
                Text("Твой дневник движения, питания и маленьких забот о себе. Без регистрации. В твоём темпе.")
            }
            NavigationLink { ReportView() } label: { Label("Отчёт для Астраси", systemImage: "doc.text") }.buttonStyle(PrimaryButtonStyle())
            NavigationLink { WorkoutHistoryView() } label: { Label("История движения", systemImage: "chart.bar") }.padding(.vertical, 8)
            NavigationLink { ScheduleView() } label: { Label("Расписание", systemImage: "calendar") }.padding(.vertical, 8)
            NavigationLink { SettingsView() } label: { Label("Настройки и резервная копия", systemImage: "gearshape") }.padding(.vertical, 8)
            Text("Мой нежный ритм · 1.0\nЛичные записи хранятся на устройстве. Интернет нужен только для перехода в ChatGPT или передачи отчёта выбранным способом.")
                .font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Мой ритм")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var reminders: ReminderService
    @Environment(\.openURL) private var openURL
    @State private var p = Preferences()
    @State private var share: SharePayload?
    @State private var importing = false
    @State private var pendingImport: AppData?
    @State private var importMessage: String?
    @State private var showImportConfirm = false
    private var workoutTime: Binding<Date> {
        Binding(get: { time(hour: p.workoutHour, minute: p.workoutMinute) }, set: {
            p.workoutHour = DayKey.calendar.component(.hour, from: $0)
            p.workoutMinute = DayKey.calendar.component(.minute, from: $0)
        })
    }
    var body: some View {
        Form {
            Section("Как к тебе обращаться") { TextField("Имя — по желанию", text: $p.name) }
            Section("Оформление") {
                Picker("Тема", selection: $p.theme) { Text("Как на iPhone").tag("system"); Text("Светлая").tag("light"); Text("Тёмная").tag("dark") }
            }
            Section("Напоминания") {
                Toggle("О тренировках", isOn: $p.workoutReminders)
                if p.workoutReminders { DatePicker("Время тренировки", selection: workoutTime, displayedComponents: .hourAndMinute) }
                Toggle("О регулярном питании", isOn: $p.mealReminders)
                if p.mealReminders {
                    ForEach(0..<3, id: \.self) { i in
                        Stepper("\(["Утро", "День", "Вечер"][i]): \(String(format: "%02d:%02d", p.mealHours[i], p.mealMinute))", value: $p.mealHours[i], in: 0...23)
                    }
                    Stepper("Минуты для напоминаний о еде: \(p.mealMinute)", value: $p.mealMinute, in: 0...59)
                }
                Button("Сохранить и разрешить уведомления") {
                    store.setPreferences(p)
                    Task { await reminders.apply(store: store, requestPermission: p.workoutReminders || p.mealReminders) }
                }
                Text(reminders.message).font(.caption).foregroundStyle(.secondary)
                Button("Открыть настройки iPhone") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                Text("Напоминания о занятиях планируются на 8 недель вперёд и обновляются при открытии дневника. При выключенном звуке или режиме фокусирования уведомление может быть тихим.").font(.caption)
            }
            Section("Данные") {
                Button { exportBackup() } label: { Label(store.recoveryRequired ? "Сохранить исходный файл" : "Экспорт JSON с фотографиями", systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label("Импортировать JSON", systemImage: "square.and.arrow.down") }
                if let importMessage { Text(importMessage).font(.caption) }
                Text("Импорт заменяет дневник после подтверждения. Предыдущий файл сохраняется в папке приложения как before-import-….json. Для переноса между устройствами сначала экспортируй копию в «Файлы». Копия содержит личные записи и фотографии.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Конфиденциальность") {
                Text("Нет аккаунта, аналитики, рекламы или отправки данных на сервер. Фото выбираются системным окном только с твоего согласия. Шаги не передаются за пределы устройства, кроме выбранного тобой текстового отчёта или копии.")
                    .font(.footnote)
            }
        }.navigationTitle("Настройки")
            .onAppear { p = store.data.preferences }
            .onChange(of: p) { value in store.setPreferences(value) }
            .onDisappear { Task { await reminders.apply(store: store) } }
            .sheet(item: $share) { ShareSheet(items: $0.items) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 100_000_000 else { throw DataError.tooLarge }
                    pendingImport = try Repository.decode(Data(contentsOf: url))
                    showImportConfirm = true
                } catch { importMessage = "Импорт не выполнен: \(error.localizedDescription)" }
            }
            .alert("Заменить дневник?", isPresented: $showImportConfirm) {
                Button("Отмена", role: .cancel) { pendingImport = nil }
                Button("Импортировать", role: .destructive) {
                    guard let pendingImport else { return }
                    do {
                        try store.importBackup(pendingImport)
                        p = store.data.preferences
                        importMessage = "Дневник восстановлен. Прежние данные сохранены в защитной копии."
                        Task { await reminders.apply(store: store) }
                    } catch { importMessage = "Импорт не выполнен: \(error.localizedDescription)" }
                    self.pendingImport = nil
                }
            } message: { Text("В копии \(pendingImport?.days.count ?? 0) дней. Текущий дневник будет заменён; его файл сохранится внутри приложения.") }
    }
    private func time(hour: Int, minute: Int) -> Date { DayKey.calendar.date(from: DateComponents(hour: hour, minute: minute))! }
    private func exportBackup() {
        do { share = SharePayload(items: [try store.backupURL()]) }
        catch { importMessage = "Не удалось создать копию: \(error.localizedDescription)" }
    }
}
