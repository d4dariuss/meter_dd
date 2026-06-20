//
//  MeterApp.swift
//  Meter
//
//  App entry point. Hosts the existing Meter web app (meter.html) inside a
//  native shell and adds a Core Location mileage tracker bridged to JavaScript.
//

import SwiftUI

@main
struct MeterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea()          // web UI draws edge-to-edge; the HTML
                .preferredColorScheme(.dark) // already handles safe-area insets
        }
    }
}
