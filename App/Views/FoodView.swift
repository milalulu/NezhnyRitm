import SwiftUI
import PhotosUI
import UIKit

struct FoodView: View {
    @EnvironmentObject private var store: JournalStore
    @State private var editing: Meal?
    @State private var deleteMeal: Meal?
    private var meals: [Meal] { store.record(on: store.selectedDate).meals }
    var body: some View {
        Page {
            DayPicker()
            SoftCard(tint: .rose) {
                Text("Питание — это забота").font(.title2.bold())
                Text("Без подсчётов и оценок. Запиши, что было на тарелке и как ты себя чувствовала.").font(.subheadline)
                Button { editing = Meal(category: "Завтрак", text: "") } label: {
                    Label("Добавить приём пищи", systemImage: "plus")
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("addMeal")
            }
            if meals.isEmpty {
                EmptyNote(symbol: "cup.and.saucer", title: "Место для твоего дня", message: "Текст, фото или несколько слов — выбери удобный способ сохранить воспоминание о еде.")
            }
            ForEach(meals) { meal in
                SoftCard(tint: .sky) {
                    HStack {
                        Text(meal.category).font(.headline)
                        Spacer()
                        Menu {
                            Button("Редактировать") { editing = meal }
                            Button("Удалить", role: .destructive) { deleteMeal = meal }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Действия с приёмом пищи")
                    }
                    if let data = meal.photo, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 18))
                            .accessibilityLabel("Фотография приёма пищи")
                    }
                    if !meal.text.isEmpty { Text(meal.text) }
                }
            }
        }.navigationTitle("Питание").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { MealEditor(meal: $0, date: store.selectedDate) }
            .alert("Удалить запись?", isPresented: Binding(get: { deleteMeal != nil }, set: { if !$0 { deleteMeal = nil } })) {
                Button("Удалить", role: .destructive) {
                    if let id = deleteMeal?.id { store.updateDay(store.selectedDate) { $0.meals.removeAll { $0.id == id } } }
                    deleteMeal = nil
                }
                Button("Отмена", role: .cancel) { deleteMeal = nil }
            }
    }
}

struct MealEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State var meal: Meal
    let date: Date
    @State private var category = "Завтрак"
    @State private var customCategory = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var loading = false
    @State private var photoError: String?
    private let categories = ["Завтрак", "Обед", "Ужин", "Перекус", "Свой вариант"]
    var body: some View {
        NavigationStack {
            Form {
                Picker("Приём пищи", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                if category == "Свой вариант" { TextField("Название приёма пищи", text: $customCategory) }
                Section("Что было на тарелке?") {
                    TextField("Несколько слов о еде", text: $meal.text, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("mealText")
                }
                Section("Фотография") {
                    if let bytes = meal.photo, let image = UIImage(data: bytes) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                        Button("Убрать фото", role: .destructive) { meal.photo = nil; photoItem = nil }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("Выбрать фотографию", systemImage: "photo") }
                    if loading { ProgressView("Готовим фото…") }
                    if let photoError { Text(photoError).foregroundStyle(.red) }
                    Text("Фото хранится внутри дневника и входит в JSON-копию. Для отчёта используется только текст.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Приём пищи").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            meal.category = category == "Свой вариант" ? customCategory.trimmingCharacters(in: .whitespacesAndNewlines) : category
                            store.updateDay(date) { day in
                                if let i = day.meals.firstIndex(where: { $0.id == meal.id }) { day.meals[i] = meal } else { day.meals.append(meal) }
                            }
                            if store.error == nil { dismiss() }
                        }.disabled(loading || (meal.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && meal.photo == nil) || (category == "Свой вариант" && customCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                            .accessibilityIdentifier("saveMeal")
                    }
                }
        }.onAppear {
            category = categories.contains(meal.category) ? meal.category : "Свой вариант"
            customCategory = meal.category
        }
        .task(id: photoItem) {
            guard let item = photoItem else { return }
            loading = true; photoError = nil
            defer { loading = false }
            do {
                guard let bytes = try await item.loadTransferable(type: Data.self), let image = UIImage(data: bytes) else {
                    photoError = "Не удалось прочитать фотографию. Попробуйте другую."; return
                }
                try Task.checkCancellation()
                let scale = min(1, 1200 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                guard let jpeg = resized.jpegData(compressionQuality: 0.75), jpeg.count <= 3_000_000 else {
                    photoError = "Фотография слишком большая. Выберите другую."; return
                }
                meal.photo = jpeg
            } catch is CancellationError {} catch { photoError = "Фото недоступно. Если оно в iCloud, сначала загрузите его на iPhone." }
        }
    }
}
