import SwiftUI

struct PetRoom: View {
    let pet: PetState
    var compact = false
    @State private var hearts = false
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [roomColor.opacity(0.45), .milk], startPoint: .top, endPoint: .bottom))
            Ellipse().fill(roomColor.opacity(0.8)).frame(height: compact ? 30 : 60).padding(.horizontal, 28).padding(.bottom, 12)
            CatArt(accessory: pet.accessory).frame(width: compact ? 110 : 230, height: compact ? 110 : 230).padding(.bottom, 20)
            if pet.decoration == "plant" { Image(systemName: "leaf.fill").font(.system(size: compact ? 28 : 48)).foregroundStyle(.green).offset(x: compact ? 60 : 120, y: -30) }
            if pet.decoration == "stars" { HStack { Image(systemName: "star.fill"); Spacer(); Image(systemName: "star.fill") }.foregroundStyle(Color.ink.opacity(0.5)).padding(26).frame(maxHeight: .infinity, alignment: .top) }
            if hearts { Image(systemName: "heart.fill").foregroundStyle(Color.rose).font(.system(size: 40)).offset(y: -180).transition(.scale.combined(with: .opacity)) }
        }.frame(height: compact ? 150 : 310)
            .onTapGesture { withAnimation { hearts.toggle() } }
            .accessibilityLabel("Комната котика \(pet.name). Коснитесь, чтобы поздороваться.")
    }
    private var roomColor: Color { pet.room == "sky" ? .sky : pet.room == "rose" ? .rose : .lavender }
}

struct PetView: View {
    @EnvironmentObject private var store: JournalStore
    @State private var name = ""
    var body: some View {
        Page {
            HStack {
                VStack(alignment: .leading) { Text(store.wellness.pet.name).font(.largeTitle.bold()); Text("Твой маленький друг").foregroundStyle(.secondary) }
                Spacer()
                Label("\(store.wellness.pet.hearts)", systemImage: "heart.fill").font(.title2).foregroundStyle(Color.accent).accessibilityIdentifier("heartBalance")
            }
            PetRoom(pet: store.wellness.pet)
            Text("Плюша рада тебе каждый день. За отметки привычек и завершённые тренировки появляются сердечки. За пропуски ничего не исчезает.").font(.subheadline)
            SoftCard {
                TextField("Имя котика", text: $name).textFieldStyle(.roundedBorder)
                Button("Сохранить имя") { store.updateWellness { $0.pet.name = name.trimmingCharacters(in: .whitespacesAndNewlines) } }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60)
            }
            SectionTitle(title: "Лавка маленьких радостей", symbol: "gift")
            ForEach(PetItem.catalog) { item in
                let owned = store.wellness.pet.owned.contains(item.id)
                SoftCard(tint: .sky) {
                    HStack { Image(systemName: item.symbol).font(.title2); Text(item.title).font(.headline); Spacer(); if !owned { Label("\(item.price)", systemImage: "heart") } }
                    if owned { Button(item.kind == "room" ? "Выбрать оформление" : "Надеть / убрать") { store.equip(item) } }
                    else { Button("Купить за сердечки") { store.buy(item) }.disabled(store.wellness.pet.hearts < item.price) }
                }
            }
            Button("Вернуть лавандовую комнату") { store.updateWellness { $0.pet.room = "lavender" } }
        }.navigationTitle("Комната Плюши").navigationBarTitleDisplayMode(.inline)
            .onAppear { name = store.wellness.pet.name }
    }
}
