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

// MARK: - Tela

struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall || family == .systemMedium {
                    PatternBackground()
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
