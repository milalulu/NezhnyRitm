import SwiftUI

struct CatArt: View {
    var accessory: String? = nil
    var animate = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Ellipse().fill(Color.ink.opacity(0.12)).frame(width: w * 0.66, height: h * 0.12).offset(y: h * 0.39)
                Capsule().fill(Color(red: 0.84, green: 0.71, blue: 0.63)).frame(width: w * 0.34, height: h * 0.13).rotationEffect(.degrees(-30)).offset(x: w * 0.29, y: h * 0.26)
                Ellipse().fill(Color(red: 0.95, green: 0.84, blue: 0.73)).frame(width: w * 0.56, height: h * 0.58).offset(y: h * 0.13)
                Ellipse().fill(Color.milk).frame(width: w * 0.31, height: h * 0.35).offset(y: h * 0.2)
                ear.frame(width: w * 0.22, height: h * 0.3).rotationEffect(.degrees(-15)).offset(x: -w * 0.22, y: -h * 0.28)
                ear.frame(width: w * 0.22, height: h * 0.3).rotationEffect(.degrees(15)).offset(x: w * 0.22, y: -h * 0.28)
                Ellipse().fill(Color(red: 0.95, green: 0.84, blue: 0.73)).frame(width: w * 0.7, height: h * 0.5).offset(y: -h * 0.15)
                HStack(spacing: w * 0.19) {
                    Capsule().fill(Color.ink).frame(width: w * 0.025, height: h * 0.065)
                    Capsule().fill(Color.ink).frame(width: w * 0.025, height: h * 0.065)
                }.offset(y: -h * 0.18)
                HStack(spacing: w * 0.28) { Circle().fill(Color.rose); Circle().fill(Color.rose) }.frame(width: w * 0.47, height: h * 0.08).offset(y: -h * 0.09)
                Image(systemName: "heart.fill").font(.system(size: w * 0.045)).foregroundStyle(Color.ink).offset(y: -h * 0.09)
                Text("ω").font(.system(size: w * 0.08, weight: .medium, design: .rounded)).foregroundStyle(Color.ink).offset(y: -h * 0.03)
                if accessory == "bow" { BowArt().frame(width: w * 0.19, height: w * 0.1).offset(y: h * 0.1) }
                if accessory == "crown" { Image(systemName: "crown.fill").font(.system(size: w * 0.18)).foregroundStyle(.yellow).offset(y: -h * 0.44) }
            }.frame(width: w, height: h).scaleEffect(breathe && animate && !reduceMotion ? 1.02 : 1)
        }
        .onAppear { if animate && !reduceMotion { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true } } }
        .accessibilityElement(children: .ignore).accessibilityLabel("Уютный котик Плюша")
    }
    private var ear: some View {
        ZStack { CatEarShape().fill(Color(red: 0.95, green: 0.84, blue: 0.73)); CatEarShape().fill(Color.rose).padding(9) }
    }
}


private struct BowArt: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                p.addLine(to: CGPoint(x: g.size.width, y: 0)); p.addLine(to: CGPoint(x: 0, y: g.size.height)); p.closeSubpath()
            }.fill(Color(red: 0.8, green: 0.32, blue: 0.5))
            Circle().fill(Color.rose).frame(width: g.size.height * 0.6, height: g.size.height * 0.6).position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }
}

private struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}
