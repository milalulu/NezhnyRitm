import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    var items: [Any]
}
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReportView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.openURL) private var openURL
    @State private var report = ""
    @State private var days = 1
    @State private var copied = false
    @State private var share: SharePayload?
    @State private var editWellbeing = false
    var body: some View {
        Page {
            DayPicker()
            Picker("Период отчёта", selection: $days) { Text("День").tag(1); Text("Неделя").tag(7) }.pickerStyle(.segmented)
            SoftCard(tint: .rose) {
                Text("Отчёт для Астраси").font(.title2.bold())
                Text("Поделиться своим днём — уже забота о себе. Астрася поможет с регулярностью без стыда и давления.").font(.subheadline)
                Button { editWellbeing = true } label: { Label("Самочувствие и комментарий", systemImage: "square.and.pencil") }
                Button {
                    report = store.periodReport(ending: store.selectedDate, days: days); copied = false
                } label: { Label("Сформировать отчёт", systemImage: "doc.text") }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("generateReport")
            }
            if !report.isEmpty {
                TextEditor(text: $report).frame(minHeight: 420).padding(12)
                    .scrollContentBackground(.hidden).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("reportText")
                Button {
                    UIPasteboard.general.string = report; copied = true
                } label: { Label(copied ? "Скопировано" : "Скопировать", systemImage: "doc.on.doc") }
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button { share = SharePayload(items: [report]) } label: { Label("Поделиться", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryButtonStyle())
                Button {
                    let appURL = URL(string: "chatgpt://")!
                    if UIApplication.shared.canOpenURL(appURL) { openURL(appURL) }
                    else { openURL(URL(string: "https://chatgpt.com/")!) }
                } label: { Label("Открыть ChatGPT", systemImage: "arrow.up.right.square") }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Text("Отчёт не отправляется автоматически. Проверь текст, скопируй его или выбери «Поделиться». В ChatGPT вставь отчёт в беседу и самостоятельно нажми отправку. Фото еды не включаются.")
                .font(.footnote).foregroundStyle(.secondary)
        }.dismissKeyboardOnScroll().navigationTitle("Отчёт для Астраси").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $share) { ShareSheet(items: $0.items) }
            .sheet(isPresented: $editWellbeing) { WellbeingEditor(date: store.selectedDate) }
            .onChange(of: days) { _ in report = ""; copied = false }
            .onChange(of: store.selectedDate) { _ in report = ""; copied = false }
    }
}
