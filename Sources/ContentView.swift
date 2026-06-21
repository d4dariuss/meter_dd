import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store:    AppState
    @EnvironmentObject var tracker:  LocationTracker
    @EnvironmentObject var tutorial: TutorialManager

    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DecideView()
                .tabItem { Label("Decide", systemImage: "bolt.fill") }
                .tag(0)
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
                .tag(1)
            SpotsView()
                .tabItem { Label("Spots", systemImage: "mappin.and.ellipse") }
                .tag(2)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(3)
            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .accentColor(.mAccent)
        .coordinateSpace(name: "tutorialSpace")
        .onPreferenceChange(TutorialAnchorKey.self) { tutorial.anchors = $0 }
        .onChange(of: tutorial.currentStep?.tab) { tab in
            if let tab = tab { withAnimation { selectedTab = tab } }
        }
        .overlay {
            if tutorial.isActive, let step = tutorial.currentStep {
                TutorialOverlay(tutorial: tutorial, step: step)
            }
        }
        .onAppear {
            let app = UITabBarAppearance()
            app.configureWithOpaqueBackground()
            app.backgroundColor = UIColor(Color.mSurface)
            UITabBar.appearance().standardAppearance   = app
            UITabBar.appearance().scrollEdgeAppearance = app

            if !hasSeenTutorial {
                // Brief delay so all views render their anchor frames first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tutorial.start()
                    hasSeenTutorial = true
                }
            }
        }
    }
}
