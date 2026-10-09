import SwiftUI
import WidgetKit

@main
struct TobiWidgets: WidgetBundle {
    var body: some Widget {
        TobiDayWidget()
    }
}

/// Calorias de hoje com o Tobi: quanto falta pra meta, os macros e o anel do dia.
struct TobiDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.kind, provider: DayProvider()) { entry in
            DayWidgetView(entry: entry)
        }
        .configurationDisplayName("Calorias de hoje")
        .description("Quanto falta pra sua meta, sempre à vista.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct DayEntry: TimelineEntry {
    let date: Date
    /// nil enquanto a pessoa não abriu o app nenhuma vez.
    let snapshot: WidgetSnapshot?
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let saved = WidgetSnapshot.load()?.on(.now)
        completion(DayEntry(date: .now, snapshot: context.isPreview ? (saved ?? .sample) : saved))
    }

    /// O resumo de agora e, à meia-noite, o dia novo zerado com as mesmas metas.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date.now
        let saved = WidgetSnapshot.load()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        let entries = [
            DayEntry(date: now, snapshot: saved?.on(now)),
            DayEntry(date: midnight, snapshot: saved?.on(midnight)),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Cores

private enum Palette {
    static let indigo = Color(red: 0.36, green: 0.32, blue: 0.92)
    static let violet = Color(red: 0.62, green: 0.42, blue: 0.96)
    static let over = Color(red: 0.98, green: 0.55, blue: 0.20)
    static let carbs = Color(red: 0.90, green: 0.26, blue: 0.33)
    static let protein = Color(red: 0.93, green: 0.70, blue: 0.13)
    static let fat = Color(red: 0.62, green: 0.32, blue: 0.86)
    static let paperTop = Color(light: Color(red: 0.99, green: 0.97, blue: 0.95), dark: Color(red: 0.12, green: 0.10, blue: 0.15))
    static let paperBottom = Color(light: Color(red: 0.95, green: 0.94, blue: 0.98), dark: Color(red: 0.08, green: 0.07, blue: 0.11))
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

private extension Int {
    /// "1.180", no jeito brasileiro, em qualquer região do iPhone.
    var br: String { formatted(.number.locale(Locale(identifier: "pt_BR"))) }
}

// MARK: - Tela

struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    PatternBackground(clearing: family == .systemSmall ? .center : UnitPoint(x: 0.2, y: 0.5))
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium: MediumDay(snapshot: entry.snapshot)
        case .accessoryCircular: CircularDay(snapshot: entry.snapshot)
        case .accessoryRectangular: RectangularDay(snapshot: entry.snapshot)
        case .accessoryInline: InlineDay(snapshot: entry.snapshot)
        default: SmallDay(snapshot: entry.snapshot)
        }
    }
}

/// A estampa de comidinhas do ícone, clareada atrás do anel pra o número respirar.
private struct PatternBackground: View {
    let clearing: UnitPoint

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.paperTop, Palette.paperBottom], startPoint: .top, endPoint: .bottom)
            Image("Pattern")
                .resizable()
                .scaledToFill()
                .opacity(0.75)
            RadialGradient(colors: [Palette.paperTop.opacity(0.92), Palette.paperTop.opacity(0)],
                           center: clearing, startRadius: 10, endRadius: 120)
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
                .stroke(Palette.indigo.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: isOver ? 1 : max(progress, 0.001))
                .stroke(
                    isOver
                        ? AnyShapeStyle(Palette.over)
                        : AnyShapeStyle(AngularGradient(colors: [Palette.indigo, Palette.violet, Palette.indigo],
                                                        center: .center)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
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
private struct Remaining {
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

private struct SmallDay: View {
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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediumDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        HStack(spacing: 18) {
            TobiRing(snapshot: snapshot, lineWidth: 10)
                .frame(width: 112, height: 112)
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
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text("\(snapshot.eaten.br) de \(snapshot.goal.br) cal")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 10)
            VStack(spacing: 7) {
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
        HStack(spacing: 7) {
            Text(letter)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 11)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * (goal > 0 ? min(value / goal, 1) : 0))
                        .widgetAccentable()
                }
            }
            .frame(height: 6)
            Text("\(Int(value.rounded()).br)/\(Int(goal.rounded()).br) g")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 66, alignment: .trailing)
        }
    }
}

// MARK: - Tela bloqueada

private struct CircularDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        Gauge(value: snapshot?.progress ?? 0) {
            Image(systemName: "pawprint.fill")
        } currentValueLabel: {
            Text(snapshot.map { $0.isOver ? "+\((-$0.remaining).br)" : $0.remaining.br } ?? "0")
                .monospacedDigit()
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

private struct RectangularDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        let remaining = Remaining(snapshot)
        VStack(alignment: .leading, spacing: 2) {
            Label("Tobi", systemImage: "pawprint.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .widgetAccentable()
            Text("\(remaining.number) \(snapshot?.isOver == true ? "acima" : "restantes")")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Gauge(value: snapshot?.progress ?? 0) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineDay: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        let remaining = Remaining(snapshot)
        Label("\(remaining.number) cal \(snapshot?.isOver == true ? "acima" : "restantes")",
              systemImage: "pawprint.fill")
    }
}

#Preview("Pequeno", as: .systemSmall) {
    TobiDayWidget()
} timeline: {
    DayEntry(date: .now, snapshot: .sample)
}

#Preview("Médio", as: .systemMedium) {
    TobiDayWidget()
} timeline: {
    DayEntry(date: .now, snapshot: .sample)
}
