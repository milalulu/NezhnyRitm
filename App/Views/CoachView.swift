import SwiftUI

// Original schematic drawings. Normalized joints make them crisp at every text/display scale.
struct ExerciseIllustration: View {
    let name: String
    @State private var secondPose = false
    private var kind: String {
        let n = name.lowercased()
        if n.contains("мостик") { return "bridge" }
        if n.contains("bird") { return "bird" }
        if n.contains("dead") { return "dead" }
        if n.contains("планка") { return "plank" }
        if n.contains("лёжа") { return "side" }
        if n.contains("подуш") { return "pillow" }
        if n.contains("выпад") { return "lunge" }
        if n.contains("наклон") { return "hinge" }
        if n.contains("ступень") { return "step" }
        if n.contains("шаг") { return "walk" }
        if n.contains("лопат") || n.contains("резин") { return "row" }
        if n.contains("присед") { return "squat" }
        return "custom"
    }
    // Head, neck, hip, two knees/feet, two elbows/hands.
    private var points: [CGPoint] {
        let rest: [(Double, Double)] = [(0.5,0.17),(0.5,0.28),(0.5,0.58),(0.4,0.71),(0.36,0.88),(0.6,0.71),(0.64,0.88),(0.36,0.42),(0.3,0.57),(0.64,0.42),(0.7,0.57)]
        var p = rest
        switch kind {
        case "bridge": p = [(0.16,0.78),(0.25,0.8),(0.52,secondPose ? 0.49 : 0.8),(0.7,0.46),(0.84,0.83),(0.67,0.49),(0.8,0.85),(0.33,0.83),(0.48,0.85),(0.34,0.79),(0.48,0.82)]
        case "bird": p = [(0.22,0.35),(0.31,0.42),(0.63,0.45),(0.66,0.67),(0.8,0.8),(0.75,secondPose ? 0.43 : 0.68),(0.9,secondPose ? 0.44 : 0.8),(0.3,0.6),(0.29,0.8),(0.17,secondPose ? 0.42 : 0.6),(0.05,secondPose ? 0.42 : 0.8)]
        case "dead": p = [(0.15,0.78),(0.25,0.8),(0.53,0.8),(0.55,0.5),(0.75,0.5),(0.69,secondPose ? 0.65 : 0.48),(0.88,secondPose ? 0.8 : 0.48),(0.3,0.56),(0.3,0.36),(0.16,secondPose ? 0.7 : 0.56),(0.04,secondPose ? 0.8 : 0.36)]
        case "side", "plank": p = [(0.17,0.54),(0.27,0.62),(0.56,secondPose ? 0.62 : 0.77),(0.72,0.77),(0.88,0.84),(0.73,kind == "side" && secondPose ? 0.47 : 0.73),(0.92,kind == "side" && secondPose ? 0.37 : 0.8),(0.3,0.83),(0.14,0.83),(0.43,0.63),(0.55,0.66)]
        case "pillow": p = [(0.45,0.2),(0.45,0.31),(0.45,0.61),(secondPose ? 0.54 : 0.59,0.64),(0.57,0.88),(0.68,0.64),(0.72,0.88),(0.43,0.48),(0.53,0.62),(0.58,0.47),(0.65,0.62)]
        case "squat": if secondPose { p = [(0.44,0.36),(0.43,0.47),(0.54,0.68),(0.31,0.7),(0.34,0.9),(0.72,0.7),(0.68,0.9),(0.29,0.47),(0.17,0.47),(0.57,0.47),(0.7,0.47)] }
        case "lunge": if secondPose { p = [(0.47,0.29),(0.47,0.4),(0.49,0.64),(0.28,0.66),(0.27,0.88),(0.68,0.86),(0.83,0.88),(0.34,0.5),(0.3,0.64),(0.59,0.52),(0.62,0.66)] }
        case "hinge": if secondPose { p = [(0.23,0.43),(0.34,0.45),(0.61,0.59),(0.48,0.73),(0.5,0.9),(0.68,0.75),(0.65,0.9),(0.35,0.62),(0.36,0.78),(0.41,0.63),(0.44,0.78)] }
        case "step": p[3] = (0.3, secondPose ? 0.5 : 0.64); p[4] = (0.3,0.7); p[6] = (0.67,0.9)
        case "walk": if secondPose { p[3] = (0.26,0.72); p[4] = (0.15,0.88); p[5] = (0.68,0.7); p[6] = (0.8,0.88) }
        case "row": p[7] = (0.33,0.45); p[8] = (secondPose ? 0.35 : 0.2,0.3); p[9] = (0.67,0.45); p[10] = (secondPose ? 0.65 : 0.8,0.3)
        default: break
        }
        return p.map { CGPoint(x: $0.0, y: $0.1) }
    }
    var body: some View {
        VStack {
            if kind == "custom" {
                Image(systemName: "figure.mind.and.body").font(.system(size: 70, weight: .ultraLight)).frame(height: 180)
                Text("Своя техника — в описании ниже").font(.caption)
            } else {
                Canvas { context, size in
                    let p = points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                    var floor = Path(); floor.move(to: CGPoint(x: 5, y: size.height * 0.92)); floor.addLine(to: CGPoint(x: size.width - 5, y: size.height * 0.92))
                    context.stroke(floor, with: .color(.secondary.opacity(0.2)), lineWidth: 3)
                    for chain in [[1,2], [2,3,4], [2,5,6], [1,7,8], [1,9,10]] {
                        var line = Path(); line.move(to: p[chain[0]])
                        for i in chain.dropFirst() { line.addLine(to: p[i]) }
                        context.stroke(line, with: .color(.accent), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: p[0].x - 13, y: p[0].y - 13, width: 26, height: 26)), with: .color(.accent))
                    if kind == "step" { context.fill(Path(CGRect(x: size.width * 0.18, y: size.height * 0.74, width: size.width * 0.22, height: size.height * 0.16)), with: .color(.lavender)) }
                    if kind == "pillow" { context.fill(Path(roundedRect: CGRect(x: size.width * 0.57, y: size.height * 0.57, width: 20, height: 25), cornerRadius: 6), with: .color(.rose)) }
                }.frame(height: 190).accessibilityHidden(true)
                Picker("Положение на схеме", selection: $secondPose) { Text("Начало").tag(false); Text("Движение").tag(true) }.pickerStyle(.segmented)
                Text("Схема: \(name). Точные ориентиры — в описании техники.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct CoachView: View {
    @EnvironmentObject private var store: JournalStore
    let date: Date
    @State private var index = 0
    @State private var editing: Exercise?
    private var session: WorkoutSession { store.session(on: date) }
    private var exercise: Exercise? { session.exercises.indices.contains(index) ? session.exercises[index] : nil }
    var body: some View {
        Page {
            if let exercise {
                Text("Упражнение \(index + 1) из \(session.exercises.count)").font(.caption).foregroundStyle(.secondary)
                SoftCard(tint: .lavender) {
                    Text(exercise.name).font(.title2.bold())
                    ExerciseIllustration(name: exercise.name)
                    Text(exercise.technique)
                }
                SoftCard(tint: .sky) {
                    Label("Можно мягче", systemImage: "leaf").font(.headline)
                    Text("Начни с меньшего числа повторений и одного подхода, выбери комфортную амплитуду. Можно увеличить паузу или пропустить упражнение. Если движение вызывает боль, остановись.")
                    Button("Настроить подходы и повторения") { editing = exercise }
                    Text("Изменится только это занятие. Еженедельный план редактируется в расписании.").font(.caption).foregroundStyle(.secondary)
                }
                ExerciseCard(exercise: exercise, session: session, date: date)
                RestTimerView()
                HStack {
                    Button("Назад") { index -= 1 }.disabled(index == 0)
                    Spacer()
                    Button(index == session.exercises.count - 1 ? "К началу" : "Дальше") { index = (index + 1) % session.exercises.count }
                }.buttonStyle(.bordered).controlSize(.large)
            } else { Text("Сегодня можно отдохнуть. Выбери день с тренировкой в календаре.") }
        }.navigationTitle("Тренер рядом").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { item in ExerciseEditor(exercise: item) { store.customizeExercise($0, on: date) } }
    }
}
