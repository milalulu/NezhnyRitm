import SwiftUI
import UserNotifications

struct PrivacyView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var privacy: PrivacyService
    @EnvironmentObject private var reminders: ReminderService
    var body: some View {
        Form {
            Section("Вход в дневник") {
                Toggle("Face ID или код-пароль iPhone", isOn: Binding(get: { privacy.enabled }, set: { value in
                    Task {
                        await privacy.setEnabled(value)
                        WidgetPublisher.publish(store.data)
                    }
                })).disabled(privacy.authenticating)
                Text(privacy.message).font(.caption)
                Text("Используется системная защита iPhone. В списке приложений дневник называется «Ритм». Содержимое скрывается в переключателе приложений, включая открытые формы и фотографии.").font(.footnote)
            }
            Section("Уведомления") {
                Toggle("Скрывать содержание", isOn: Binding(get: { store.wellness.privateNotifications }, set: { value in
                    store.updateWellness { $0.privateNotifications = value }
                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
                    Task { await reminders.apply(store: store) }
                }))
                Text("При включённом переключателе уведомления показывают только нейтральное напоминание. Таймер на экране продолжает работать.").font(.caption)
            }
            Section("Виджеты на домашнем экране") {
                if WidgetPublisher.available {
                    Toggle("Показывать планы и питомца", isOn: Binding(get: { store.wellness.shareWithWidgets }, set: { value in
                        store.updateWellness { $0.shareWithWidgets = value }
                    })).disabled(privacy.enabled)
                    Text(privacy.enabled ? "При защите входа виджеты скрывают данные. iOS может обновить ранее показанный виджет с задержкой; для немедленного скрытия удали его с домашнего экрана." : "Виджет получает только план на сегодня, названия привычек, количество отметок и оформление котика. Питание, фото, сон и личные комментарии не передаются.").font(.footnote)
                    Text("Добавь «Ритм» через меню добавления виджетов iPhone. Нажатие открывает дневник; отметки доступны внутри приложения.").font(.caption)
                } else {
                    Text("Эта сборка работает без App Groups и расширений. Для виджетов нужен вариант Full и подпись, поддерживающая его App Group. Все дневники и питомец доступны здесь без виджетов.").font(.footnote)
                }
            }
            Section("Локальные данные") {
                Text("Нет аккаунта, рекламы или аналитики. Дневник и фото остаются на устройстве; системная резервная копия iPhone может включать данные приложения. JSON-копия и отчёт покидают приложение только по твоему действию. Импорт не меняет настройку блокировки этого iPhone.").font(.footnote)
            }
        }.navigationTitle("Приватность")
    }
}
