import SwiftUI
import UIKit

// MARK: – Keyboard dismiss

extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Adds a Done button above the keyboard for decimal-pad and number-pad fields.
    func withKeyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.hideKeyboard() }
                    .foregroundColor(.mAccent)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: – Level color

func levelColor(_ lv: String) -> Color {
    switch lv {
    case "green":  return .mGreen
    case "amber":  return .mAmber
    case "orange": return .mOrange
    case "red":    return .mRed
    default:       return .mFaint
    }
}

// MARK: – Format helpers

func fmt(_ v: Double?, prefix: String = "", suffix: String = "", decimals: Int = 2) -> String {
    guard let v = v, v.isFinite else { return "—" }
    return "\(prefix)\(String(format: "%.\(decimals)f", v))\(suffix)"
}

func fmtDuration(_ seconds: TimeInterval) -> String {
    let s = Int(max(0, seconds))
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%d:%02d", m, sec)
}

// MARK: – Card container

struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .background(Color.mSurface)
            .cornerRadius(10)
    }
}

// MARK: – Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.mFaint)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: – Thin separator

struct MLine: View {
    var body: some View { Color.mLine.frame(height: 1) }
}

// MARK: – Badge

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: – Chip toggle button

struct Chip: View {
    let title: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(active ? .mAccent : .mMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.mAccent.opacity(0.15) : Color.mElev)
                .cornerRadius(14)
        }
    }
}

// MARK: – Stat row

struct StatRow: View {
    let label: String
    let value: String
    var highlight: Color? = nil
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.mMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(highlight ?? .mText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: – Live elapsed timer (isolated ticker — only this Text re-renders each second)

struct LiveTimer: View {
    let since: Date
    var prefix: String = ""
    var color: Color   = .mText
    var font: Font     = .system(size: 13, design: .monospaced)

    @State private var elapsed: TimeInterval = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(prefix + fmtDuration(elapsed))
            .font(font)
            .foregroundColor(color)
            .onReceive(ticker) { _ in elapsed = Date().timeIntervalSince(since) }
            .onAppear { elapsed = Date().timeIntervalSince(since) }
    }
}

// MARK: – GPS pill

struct GpsPill: View {
    @EnvironmentObject var tracker: LocationTracker

    private var miles: Double { tracker.meters / 1609.344 }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tracker.isTracking ? Color.mGreen : Color.mFaint)
                .frame(width: 8, height: 8)
            Text(String(format: "GPS %.2f mi", miles))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mText)
                .fixedSize()
            Button(tracker.isTracking ? "Stop" : "Track") {
                if tracker.isTracking { tracker.stop() }
                else {
                    if tracker.authStatus == .notDetermined {
                        tracker.requestWhenInUse()
                    }
                    tracker.start()
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.mAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.mElev)
        .cornerRadius(20)
    }
}
