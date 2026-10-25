import SwiftUI

struct Page<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(20).padding(.bottom, 20).frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
        }
        .background(scheme == .dark ? Color(uiColor: .systemBackground) : .milk)
    }
}

struct SoftCard<Content: View>: View {
    var tint: Color = .lavender
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(tint.opacity(scheme == .dark ? 0.13 : 0.30), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 12)
            .foregroundStyle(Color.ink)
            .background(LinearGradient(colors: [.rose, .lavender], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

struct DayPicker: View {
    @EnvironmentObject private var store: JournalStore
    var body: some View {
        DatePicker("День дневника", selection: $store.selectedDate, displayedComponents: .date)
            .datePickerStyle(.compact)
            .accessibilityIdentifier("dayPicker")
    }
}

struct SectionTitle: View {
    var title: String
    var symbol: String
    var body: some View {
        Label(title, systemImage: symbol).font(.title3.weight(.semibold))
    }
}

struct EmptyNote: View {
    var symbol: String
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(Color.accent)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

extension View {
    func dismissKeyboardOnScroll() -> some View { scrollDismissesKeyboard(.interactively) }
}
