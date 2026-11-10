import SwiftUI

@main
struct TorwartFitApp: App {
    @StateObject private var store = Store()

    init() {
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.lime)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0
    @State private var onboarding = false

    var body: some View {
        TabView(selection: $tab) {
            TodayView().tabItem { Label("Heute", systemImage: "circle.circle") }.tag(0)
            TrainingView().tabItem { Label("Training", systemImage: "dumbbell.fill") }.tag(1)
            NutritionView().tabItem { Label("Essen", systemImage: "fork.knife") }.tag(2)
            CoachView().tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right.fill") }.tag(3)
            StatsView().tabItem { Label("Statistik", systemImage: "chart.bar.fill") }.tag(4)
        }
        .fullScreenCover(item: $store.launch) { l in
            PlayerView(launch: l, store: store).environmentObject(store)
        }
        .fullScreenCover(item: $store.runLaunch) { r in
            RunTrackerView(launch: r, store: store).environmentObject(store)
        }
        .sheet(isPresented: $onboarding) {
            GoalPickerView(first: true).environmentObject(store).interactiveDismissDisabled()
        }
        .onAppear { onboarding = store.s.goal == nil && store.s.programs.isEmpty && store.s.logs.isEmpty }
        .task { await store.refreshHealth() }
        .onChange(of: phase) { _, p in if p == .active { Task { await store.refreshHealth() } } }
    }
}
