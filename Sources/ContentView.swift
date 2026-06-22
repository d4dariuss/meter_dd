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
        // Shift glow — always present so animation state is preserved; opacity drives visibility
        .overlay {
            ShiftGlowBorder(active: store.activeShift != nil)
                .allowsHitTesting(false)
        }
        // Tutorial renders on top of everything including the glow
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tutorial.start()
                    hasSeenTutorial = true
                }
            }
        }
    }
}

// MARK: – Screen-edge shift glow border

private struct ShiftGlowBorder: View {
    let active: Bool

    @State private var glow = false

    // Uses the private display corner radius so the rect matches the actual device shape.
    // Falls back to 44 (correct for most modern iPhones) if unavailable.
    private var screenRadius: CGFloat {
        (UIScreen.main.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 44
    }

    var body: some View {
        let opacity = active ? (glow ? 1.0 : 0.4) : 0.0
        let shadowR = active ? (glow ? 20.0 : 8.0)  : 0.0

        RoundedRectangle(cornerRadius: screenRadius)
            .stroke(Color.mAccent.opacity(opacity), lineWidth: 2.5)
            .shadow(color: Color.mAccent.opacity(active ? (glow ? 0.65 : 0.2) : 0), radius: shadowR)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: active)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glow)
            .onAppear { glow = true }
    }
}
