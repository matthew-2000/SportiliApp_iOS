import SwiftUI
import WidgetKit
#if os(iOS)
import ActivityKit
#endif

struct WorkoutEntry: TimelineEntry { let date: Date; let workout: WorkoutSurface? }
struct WorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry { .init(date: Date(), workout: nil) }
    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) { completion(.init(date: Date(), workout: WorkoutSurface.current)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: Date(), workout: WorkoutSurface.current)], policy: .never))
    }
}
struct WorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let workout: WorkoutSurface?
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "dumbbell.fill")
                    Text(workout.map { "\($0.count)" } ?? "Apri").font(.caption)
                }
            case .accessoryInline:
                Text(workout.map { "\($0.name) · \($0.count) es." } ?? "Apri la scheda")
            default:
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout?.name ?? "Apri la scheda").font(.headline).lineLimit(2)
                    if let workout { Text("\(workout.count) esercizi").font(.caption) }
                    else { Text("Scegli un giorno nell’app").font(.caption) }
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(workout?.url ?? URL(string: "sportiliapp://day"))
    }
}
struct WorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorkoutWidget", provider: WorkoutProvider()) { entry in
            WorkoutWidgetView(workout: entry.workout)
        }
        .configurationDisplayName("Scheda")
        .description("Il giorno scelto nell’app.")
#if os(watchOS)
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
#else
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
#endif
    }
}
#if os(iOS)
@available(iOSApplicationExtension 16.2, *)
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            VStack {
                Text(context.isStale ? "Recupero terminato" : "Recupero")
                Text(timerInterval: Date.distantPast...context.state.deadline, countsDown: true).monospacedDigit()
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.isStale ? "Recupero terminato" : "Recupero")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date.distantPast...context.state.deadline, countsDown: true).monospacedDigit()
                }
            } compactLeading: { Image(systemName: "timer") }
            compactTrailing: { Text(timerInterval: Date.distantPast...context.state.deadline, countsDown: true).monospacedDigit().frame(width: 48) }
            minimal: { Image(systemName: "timer") }
            .widgetURL(URL(string: "sportiliapp://rest"))
        }
    }
}
#endif
@main
struct SportiliWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutWidget()
#if os(iOS)
        RestLiveActivity()
#endif
    }
}
