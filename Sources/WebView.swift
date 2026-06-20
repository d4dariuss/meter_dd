//
//  WebView.swift
//  Meter
//
//  Loads the bundled meter.html in a WKWebView and wires a two-way bridge:
//    JS  -> Swift : window.webkit.messageHandlers.meter.postMessage({action:"..."})
//    Swift -> JS  : window.MeterNative.onUpdate(miles, accuracy, speedMph, tracking)
//
//  bridge.js is injected at document end so meter.html stays byte-for-byte the
//  same file you already use and test. Replacing meter.html later and rebuilding
//  keeps your saved data, because the file:// origin does not change.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let tracker: LocationTracker

    func makeCoordinator() -> Coordinator { Coordinator(tracker: tracker) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        // JS -> Swift channel named "meter"
        controller.add(context.coordinator, name: "meter")

        // Inject the bridge JS at document end (keeps meter.html unchanged)
        if let url = Bundle.main.url(forResource: "bridge", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            controller.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        // Persistent data store so localStorage survives app restarts.
        config.websiteDataStore = .default()

        // Start with the screen bounds so the viewport size is known at load time,
        // not the SwiftUI-assigned frame which arrives after the WKWebView is created.
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
        webView.scrollView.bounces = false
        // Prevent the OS from adding safe-area content insets on top of what
        // the HTML already handles via env(safe-area-inset-*). Without .never,
        // the content is double-inset producing large black gaps at top/bottom.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.contentOffset = .zero
        webView.isOpaque = false
        // Match the HTML --bg colour so any residual gap blends in rather than
        // showing as a hard black band.
        webView.backgroundColor = UIColor(red: 14/255, green: 18/255, blue: 23/255, alpha: 1)
        context.coordinator.webView = webView

        // Swift -> JS: push live GPS numbers into the web app.
        tracker.onUpdate = { [weak webView] miles, accuracy, speed, tracking in
            let js = String(
                format: "window.MeterNative && window.MeterNative.onUpdate(%.4f,%.1f,%.1f,%@);",
                miles, accuracy, speed, tracking ? "true" : "false"
            )
            DispatchQueue.main.async { webView?.evaluateJavaScript(js, completionHandler: nil) }
        }

        if let html = Bundle.main.url(forResource: "meter", withExtension: "html") {
            webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator (receives JS messages)

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let tracker: LocationTracker
        weak var webView: WKWebView?

        init(tracker: LocationTracker) { self.tracker = tracker }

        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "meter",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "requestWhenInUse": tracker.requestWhenInUse()
            case "requestAlways":    tracker.requestAlways()
            case "startTracking":    tracker.requestWhenInUse(); tracker.start()
            case "stopTracking":     tracker.stop()
            default: break
            }
        }
    }
}
