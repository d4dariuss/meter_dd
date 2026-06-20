//
//  ContentView.swift
//  Meter
//

import SwiftUI

struct ContentView: View {
    // One tracker for the app's lifetime. WebView reads/writes it through the bridge.
    @StateObject private var tracker = LocationTracker()

    var body: some View {
        WebView(tracker: tracker)
            .ignoresSafeArea()
            .background(Color.black)
    }
}
