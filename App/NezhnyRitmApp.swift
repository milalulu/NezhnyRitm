import SwiftUI

@main
struct NezhnyRitmApp: App {
    @StateObject private var store: JournalStore
    @StateObject private var health = HealthService()
    @StateObject private var privacy = PrivacyService()
    @StateObject private var reminders = ReminderService()
    @Environment(\.scenePhase) private var phase

    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-journal.json")
            try? FileManager.default.removeItem(at: url)
            let repository = Repository(url: url)
            if ProcessInfo.processInfo.arguments.contains("--coach-testing") {
                var fixture = AppData()
                let weekday = DayKey.calendar.component(.weekday, from: Date())
                fixture.schedule[weekday - 1].exercises = SeedProgram.make()[0].exercises
                fixture.schedule[weekday - 1].title = "Ягодицы и бёдра"
                fixture.preferences.theme = "dark"
                try? repository.save(fixture)
            }
            _store = StateObject(wrappedValue: JournalStore(repository: repository))
        } else { _store = StateObject(wrappedValue: JournalStore()) }
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store).environmentObject(health).environmentObject(reminders).environmentObject(privacy)
                .background(PrivacyWindowAnchor(privacy: privacy))
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .tint(.accent)
                .preferredColorScheme(store.data.preferences.theme == "system" ? nil : (store.data.preferences.theme == "dark" ? .dark : .light))
                .task { await refresh() }
                .onChange(of: phase) { value in
                    if value == .active { Task { await refresh() } }
                }
                .onChange(of: store.selectedDate) { _ in Task { await health.sync(store: store) } }
                .alert("Дневник", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("Понятно", role: .cancel) { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
    private func refresh() async {
        store.reconcileHistory()
        store.reconcileRoutines()
        WidgetPublisher.publish(store.data)
        await health.sync(store: store)
        await reminders.apply(store: store)
    }
}

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { DashboardView() }.tabItem { Label("Сегодня", systemImage: "sun.max") }.tag(0)
            NavigationStack { WorkoutView() }.tabItem { Label("Движение", systemImage: "figure.mind.and.body") }.tag(1)
            NavigationStack { FoodView() }.tabItem { Label("Питание", systemImage: "fork.knife") }.tag(2)
            NavigationStack { ActivityView() }.tabItem { Label("Шаги", systemImage: "figure.walk") }.tag(3)
            NavigationStack { MoreView() }.tabItem { Label("Мой ритм", systemImage: "heart.text.square") }.tag(4)
        }
    }
}
