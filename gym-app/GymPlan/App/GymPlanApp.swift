import SwiftUI
import UserNotifications

@main
struct GymPlanApp: App {
    @State private var store = Store()

    init() {
        RestNotifier.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}

enum AppTab: Hashable {
    case today, plan, food, progress, exercises
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Heute", systemImage: "flame.fill", value: AppTab.today) {
                TodayView(tab: $tab)
            }
            Tab("Plan", systemImage: "calendar", value: AppTab.plan) {
                PlanView()
            }
            Tab("Essen", systemImage: "fork.knife", value: AppTab.food) {
                NutritionView()
            }
            Tab("Fortschritt", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTab()
            }
            Tab("Übungen", systemImage: "dumbbell.fill", value: AppTab.exercises) {
                ExercisesView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(isPresented: $store.showWorkout) {
            WorkoutView()
        }
        .sheet(isPresented: $store.showGenerator) {
            GeneratorView()
        }
        .onAppear {
            if store.plan == nil { store.showGenerator = true }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background { store.save() }
        }
    }
}

/// Meldet sich, wenn die Satzpause vorbei ist – auch bei gesperrtem iPhone.
final class RestNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestNotifier()
    private let id = "rest-timer"

    func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(seconds: Int, next exerciseName: String?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Pause vorbei"
        content.body = exerciseName.map { "Nächster Satz: \($0)" } ?? "Weiter geht's mit dem nächsten Satz."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
