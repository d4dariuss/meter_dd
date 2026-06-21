import SwiftUI

@main
struct MeterApp: App {
    @StateObject private var store    = AppState()
    @StateObject private var tracker  = LocationTracker()
    @StateObject private var tutorial = TutorialManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .environmentObject(tutorial)
                .preferredColorScheme(.dark)
        }
    }
}
