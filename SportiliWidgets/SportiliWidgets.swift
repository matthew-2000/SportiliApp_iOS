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
#if os(iOS)
        PhoneWorkoutWidgetView(workout: workout)
            .widgetURL(workout?.url ?? URL(string: "sportiliapp://day"))
#else
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
#endif
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
// The extension keeps the app's warm palette without linking app or Firebase code.
private struct SurfacePalette {
    let scheme: ColorScheme

    var background: Color { color(light: 0xFFFBF7, dark: 0x211A15) }
    var foreground: Color { color(light: 0x211A15, dark: 0xF1E8E0) }
    var secondary: Color { color(light: 0x51443A, dark: 0xD8C3B3) }
    var accent: Color { color(light: 0x9B4A00, dark: 0xFFB870) }
    var accentSurface: Color { color(light: 0xF2E5DA, dark: 0x3C3027) }
    static let islandAccent = Color(red: 1, green: 184 / 255, blue: 112 / 255)

    private func color(light: UInt32, dark: UInt32) -> Color {
        let hex = scheme == .dark ? dark : light
        return Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct PhoneWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let workout: WorkoutSurface?

    private var palette: SurfacePalette { SurfacePalette(scheme: scheme) }
    private var exerciseCount: String {
        guard let count = workout?.count else { return "Scegli un giorno nell’app" }
        return count == 1 ? "1 esercizio" : "\(count) esercizi"
    }
    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryInline || family == .accessoryRectangular
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 17, weight: .semibold))
                    Text(workout.map { "\($0.count) es." } ?? "Scheda")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            case .accessoryInline:
                Label {
                    Text(workout.map { "\($0.name) · \($0.count) es." } ?? "Apri la scheda")
                } icon: {
                    Image(systemName: "figure.strengthtraining.traditional")
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3.weight(.semibold))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout?.name ?? "La tua scheda")
                            .font(.headline)
                            .lineLimit(1)
                        Text(exerciseCount)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                homeContent
            }
        }
        // Lock Screen accessories use the system's monochrome/vibrancy treatment.
        .containerBackground(for: .widget) {
            if !isAccessory { palette.background }
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SportiliApp", systemImage: "figure.strengthtraining.traditional")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent)

            Spacer(minLength: 0)

            Text(workout?.name ?? "La tua scheda")
                .font(.system(size: family == .systemSmall ? 24 : 28, weight: .semibold))
                .foregroundStyle(palette.foreground)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                Text(exerciseCount)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)
                    .background(palette.accentSurface, in: Circle())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct RestCountdown: View {
    let deadline: Date
    let ended: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if ended {
                Text("0:00")
            } else {
                Text(timerInterval: Date.distantPast...deadline, countsDown: true)
            }
        }
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.trailing)
    }
}

private struct RestLockScreenView: View {
    @Environment(\.colorScheme) private var scheme
    let deadline: Date
    let ended: Bool
    let exerciseName: String?

    private var palette: SurfacePalette { SurfacePalette(scheme: scheme) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ended ? "checkmark" : "timer")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 44, height: 44)
                .background(palette.accentSurface, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(ended ? "Recupero terminato" : "Recupero")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(2)
                if !ended {
                    Text(exerciseName ?? "Tempo rimanente")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            RestCountdown(deadline: deadline, ended: ended, size: 34)
                .foregroundStyle(palette.accent)
                .frame(width: 108, alignment: .trailing)
        }
        .padding(16)
        .activityBackgroundTint(palette.background)
        .activitySystemActionForegroundColor(palette.accent)
        .widgetURL(URL(string: "sportiliapp://rest"))
    }
}

@available(iOSApplicationExtension 16.2, *)
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestAttributes.self) { context in
            RestLockScreenView(deadline: context.state.deadline, ended: context.isStale,
                exerciseName: context.attributes.exerciseName)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(context.isStale ? "Terminato" : "Recupero",
                              systemImage: context.isStale ? "checkmark.circle.fill" : "timer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SurfacePalette.islandAccent)
                        if let name = context.attributes.exerciseName {
                            Text(name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(deadline: context.state.deadline, ended: context.isStale, size: 34)
                        .foregroundStyle(.white)
                        .frame(width: 112, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale {
                        Text("Puoi iniziare la prossima serie")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let start = context.state.startedAt {
                        ProgressView(timerInterval: start...context.state.deadline, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(SurfacePalette.islandAccent)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)
                    }
                }
            } compactLeading: {
                Image(systemName: context.isStale ? "checkmark" : "timer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SurfacePalette.islandAccent)
            } compactTrailing: {
                RestCountdown(deadline: context.state.deadline, ended: context.isStale, size: 16)
                    .foregroundStyle(.white)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                Image(systemName: context.isStale ? "checkmark" : "timer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SurfacePalette.islandAccent)
            }
            .keylineTint(SurfacePalette.islandAccent)
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
