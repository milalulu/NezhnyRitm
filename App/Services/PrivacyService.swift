import SwiftUI
import LocalAuthentication
import Combine

@MainActor
final class PrivacyService: ObservableObject {
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "privacyLock")
    @Published private(set) var locked = UserDefaults.standard.bool(forKey: "privacyLock")
    @Published private(set) var active = true
    @Published private(set) var authenticating = false
    @Published var message = ""
    private var shield: UIWindow?
    private var observers: Set<AnyCancellable> = []
    init() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [weak self] _ in
            self?.active = false; self?.updateShield()
        }.store(in: &observers)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).sink { [weak self] _ in
            guard let self else { return }; self.locked = self.enabled; self.updateShield()
        }.store(in: &observers)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.active = true; self?.updateShield()
        }.store(in: &observers)
    }
    func attach(to scene: UIWindowScene) {
        guard shield == nil else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: PrivacyCover().environmentObject(self))
        window.backgroundColor = .systemBackground
        shield = window
        updateShield()
    }
    private func updateShield() { shield?.isHidden = active && !locked }
    func authenticate() async -> Bool {
        guard !authenticating else { return false }
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = "Сначала установи код-пароль устройства в настройках iPhone."; return false
        }
        authenticating = true
        defer { authenticating = false }
        do { return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Открыть личный дневник Ритм") }
        catch { message = "Дневник закрыт. Можно попробовать ещё раз или использовать код-пароль iPhone."; return false }
    }
    func unlock() async {
        if await authenticate(), shield?.windowScene?.activationState != .background { locked = false; message = ""; updateShield() }
    }
    func setEnabled(_ value: Bool) async {
        guard await authenticate() else { return }
        enabled = value
        UserDefaults.standard.set(value, forKey: "privacyLock")
        locked = !active && value
        message = value ? "Защита включена. При следующем открытии потребуется Face ID или код-пароль iPhone." : "Защита выключена."
        updateShield()
    }
}

private struct PrivacyCover: View {
    @EnvironmentObject var privacy: PrivacyService
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles").font(.system(size: 60, weight: .ultraLight)).foregroundStyle(Color.accent)
            Text("Ритм").font(.largeTitle.bold())
            if privacy.active && privacy.locked {
                Button { Task { await privacy.unlock() } } label: { Label("Открыть дневник", systemImage: "lock.open") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(privacy.authenticating)
                Text(privacy.message).font(.footnote).multilineTextAlignment(.center)
            }
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(uiColor: .systemBackground))
            .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}

struct PrivacyWindowAnchor: UIViewRepresentable {
    let privacy: PrivacyService
    func makeUIView(context: Context) -> Anchor {
        let view = Anchor(); view.privacy = privacy; return view
    }
    func updateUIView(_ uiView: Anchor, context: Context) {
        if let scene = uiView.window?.windowScene { privacy.attach(to: scene) }
    }
    final class Anchor: UIView {
        weak var privacy: PrivacyService?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { privacy?.attach(to: scene) }
        }
    }
}
