import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    var body: some View {
        TabView {
            DecideView()
                .tabItem { Label("Decide", systemImage: "bolt.fill") }
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
            SpotsView()
                .tabItem { Label("Spots", systemImage: "mappin.and.ellipse") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .accentColor(.mAccent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.mSurface)
            UITabBar.appearance().standardAppearance   = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            if !hasSeenTutorial { showTutorial = true }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView {
                hasSeenTutorial = true
                showTutorial    = false
            }
        }
    }
}
