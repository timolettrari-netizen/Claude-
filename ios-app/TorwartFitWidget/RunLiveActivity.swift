import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TorwartFitWidgetBundle: WidgetBundle {
    var body: some Widget {
        RunLiveActivity()
    }
}

private let lime = Color(red: 0.776, green: 0.957, blue: 0.196)
private let muted = Color.white.opacity(0.6)

private extension RunActivityAttributes.ContentState {
    var color: Color { phaseEnd == nil ? lime : (hard ? .orange : .cyan) }
    var paused: Bool { pausedElapsed != nil }

    var details: String {
        var parts: [String] = []
        if km > 0.01 { parts.append(String(format: "%.2f km", km).replacingOccurrences(of: ".", with: ",")) }
        if !pace.isEmpty { parts.append(pace) }
        if let hr { parts.append("♥ \(hr)") }
        return parts.joined(separator: " · ")
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds), h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s % 60) : String(format: "%d:%02d", m, s % 60)
    }
}

/// Gesamtzeit: läuft live mit, steht still bei Pause
private struct ElapsedText: View {
    let state: RunActivityAttributes.ContentState
    var body: some View {
        if let p = state.pausedElapsed {
            Text(RunActivityAttributes.ContentState.clock(p))
        } else {
            Text(state.startedAt, style: .timer)
        }
    }
}

/// Countdown des Abschnitts (oder Gesamtzeit, wenn es keinen Abschnitt gibt)
private struct MainTimer: View {
    let state: RunActivityAttributes.ContentState
    var body: some View {
        if let end = state.phaseEnd, !state.paused {
            Text(end, style: .timer)
        } else {
            ElapsedText(state: state)
        }
    }
}

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(lime)
        } dynamicIsland: { context in
            let st = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(st.paused ? "PAUSE" : st.phase.uppercased())
                            .font(.system(size: 20, weight: .heavy)).italic()
                            .foregroundStyle(st.paused ? muted : st.color)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(context.attributes.icon) \(context.attributes.title)")
                            .font(.caption2).foregroundStyle(muted).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainTimer(state: st)
                        .font(.system(size: 28, weight: .heavy).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(st.details).font(.subheadline.weight(.semibold))
                        Spacer()
                        if let n = st.next { Text("Danach: \(n)").font(.caption).foregroundStyle(muted).lineLimit(1) }
                    }
                }
            } compactLeading: {
                Text(context.attributes.icon)
            } compactTrailing: {
                MainTimer(state: st)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(st.paused ? muted : st.color)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 48)
            } minimal: {
                Text(context.attributes.icon)
            }
            .keylineTint(st.color)
        }
    }
}

private struct LockScreenView: View {
    let attributes: RunActivityAttributes
    let state: RunActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(attributes.icon) \(attributes.title)").font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: state.paused ? "pause.fill" : "stopwatch")
                    ElapsedText(state: state).monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(muted)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(state.paused ? "PAUSE" : state.phase.uppercased())
                    .font(.system(size: 30, weight: .heavy)).italic()
                    .foregroundStyle(state.paused ? muted : state.color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                if state.phaseEnd != nil && !state.paused {
                    MainTimer(state: state)
                        .font(.system(size: 34, weight: .heavy).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130, alignment: .trailing)
                }
            }
            HStack {
                Text(state.details.isEmpty ? " " : state.details).font(.subheadline.weight(.semibold))
                Spacer()
                if let n = state.next { Text("Danach: \(n)").font(.caption).foregroundStyle(muted).lineLimit(1) }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}
