import SwiftUI

@main
struct MeterApp: App {
    @StateObject private var store   = AppState()
    @StateObject private var tracker = LocationTracker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(tracker)
                .preferredColorScheme(.dark)
        }
    }
}
