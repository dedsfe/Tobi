import SwiftUI
import WidgetKit

// O visual dos widgets, usado pelo widget e pela tela de widget do onboarding (a mesma cara nos dois).

// MARK: - Cores

private enum Palette {
    static let indigo = Color(red: 0.36, green: 0.32, blue: 0.92)
    static let violet = Color(red: 0.62, green: 0.42, blue: 0.96)
    static let over = Color(red: 0.98, green: 0.55, blue: 0.20)
    static let carbs = Color(red: 0.90, green: 0.26, blue: 0.33)
    static let protein = Color(red: 0.93, green: 0.70, blue: 0.13)
    static let fat = Color(red: 0.62, green: 0.32, blue: 0.86)
    static let paperTop = Color(widgetLight: Color(red: 0.99, green: 0.97, blue: 0.95), dark: Color(red: 0.12, green: 0.10, blue: 0.15))
    static let paperBottom = Color(widgetLight: Color(red: 0.95, green: 0.94, blue: 0.98), dark: Color(red: 0.08, green: 0.07, blue: 0.11))
}

private extension Color {
    init(widgetLight light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

extension Int {
    /// "1.180", no jeito brasileiro, em qualquer região do iPhone.
    var br: String { formatted(.number.locale(Locale(identifier: "pt_BR"))) }
}

/// A estampa de comidinhas do ícone, bem de leve: textura de papel, nunca disputando com o número.
struct PatternBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.paperTop, Palette.paperBottom], startPoint: .top, endPoint: .bottom)
            Image("Pattern")
                .resizable()
                .scaledToFill()
                .opacity(colorScheme == .dark ? 0.16 : 0.28)
        }
    }
}

/// O anel de calorias com o Tobi no meio. Passou da meta: o anel fica laranja e cheio.
private struct TobiRing: View {
    let snapshot: WidgetSnapshot?
    var lineWidth: CGFloat = 9

    private var progress: Double { snapshot?.progress ?? 0 }
    private var isOver: Bool { snapshot?.isOver ?? false }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.indigo.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: isOver ? 1 : progress)
                .stroke(
                    isOver
                        ? AnyShapeStyle(Palette.over)
                        : AnyShapeStyle(AngularGradient(colors: [Palette.indigo, Palette.violet, Palette.indigo],
                                                        center: .center)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(isOver || progress > 0 ? 1 : 0)
                .widgetAccentable()
            Image("TobiFace")
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .scaledToFit()
                .padding(lineWidth + 6)
        }
    }
}

/// "820" e "restantes", ou "+120" e "acima da meta".
struct Remaining {
    let number: String
    let label: String
    let color: Color?

    init(_ snapshot: WidgetSnapshot?) {
        guard let snapshot else {
            number = "0"
            label = "cal hoje"
            color = nil
            return
        }
        if snapshot.isOver {
            number = "+\((-snapshot.remaining).br)"
            label = "acima da meta"
            color = Palette.over
        } else {
            number = snapshot.remaining.br
            label = "restantes"
            color = nil
        }
    }
}

// MARK: - Tela de início

struct SmallDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        let remaining = Remaining(snapshot)
        VStack(spacing: 6) {
            TobiRing(snapshot: snapshot, lineWidth: 8)
                .frame(width: 82, height: 82)
            if snapshot == nil {
                Text("Anote sua primeira refeição")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                VStack(spacing: 0) {
                    Text(remaining.number)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(remaining.color ?? .primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .widgetAccentable()
                    Text(remaining.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediumDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        HStack(spacing: 16) {
            TobiRing(snapshot: snapshot, lineWidth: 10)
                .frame(width: 106, height: 106)
            if let snapshot {
                details(snapshot)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bora começar?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Anote o que comeu e o Tobi conta as calorias pra você.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func details(_ snapshot: WidgetSnapshot) -> some View {
        let remaining = Remaining(snapshot)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(remaining.number)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(remaining.color ?? .primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text(remaining.label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.65))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text("\(snapshot.eaten.br) de \(snapshot.goal.br) cal")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.65))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 10)
            Grid(alignment: .leading, horizontalSpacing: 7, verticalSpacing: 7) {
                MacroBar(letter: "C", value: snapshot.carbs, goal: snapshot.carbsGoal, color: Palette.carbs)
                MacroBar(letter: "P", value: snapshot.protein, goal: snapshot.proteinGoal, color: Palette.protein)
                MacroBar(letter: "G", value: snapshot.fat, goal: snapshot.fatGoal, color: Palette.fat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "C ▬▬▬── 140/250 g": a letra com a cor do macro, a barra e os gramas.
private struct MacroBar: View {
    let letter: String
    let value: Double
    let goal: Double
    let color: Color

    var body: some View {
        GridRow {
            Text(letter)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.22))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * (goal > 0 ? min(value / goal, 1) : 0))
                        .widgetAccentable()
                }
            }
            .frame(height: 7)
            Text("\(Int(value.rounded()).br)/\(Int(goal.rounded()).br) g")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.7))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .gridColumnAlignment(.trailing)
        }
    }
}

