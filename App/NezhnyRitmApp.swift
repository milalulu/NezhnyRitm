import SwiftUI

@main
struct NezhnyRitmApp: App {
    @StateObject private var store: JournalStore
    @StateObject private var health = HealthService()
    @StateObject private var reminders = ReminderService()
    @Environment(\.scenePhase) private var phase

    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-journal.json")
            try? FileManager.default.removeItem(at: url)
            _store = StateObject(wrappedValue: JournalStore(repository: Repository(url: url)))
        } else { _store = StateObject(wrappedValue: JournalStore()) }
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store).environmentObject(health).environmentObject(reminders)
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
