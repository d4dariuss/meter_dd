import SwiftUI

// MARK: – Step definition

struct TutorialStep {
    let tab:       Int     // 0=Decide 1=Log 2=Spots 3=Stats 4=Settings
    let anchorID:  String
    let title:     String
    let body:      String
}

// MARK: – Manager

class TutorialManager: ObservableObject {
    @Published var isActive:   Bool = false
    @Published var stepIndex:  Int  = 0
    @Published var anchors:    [String: CGRect] = [:]

    let steps: [TutorialStep] = [

        // ── Decide ──────────────────────────────────────────────────────────
        TutorialStep(tab: 0, anchorID: "ar-header",
                     title: "Rolling AR",
                     body: "Estimated from your last 100 offers. Green means you're Platinum-safe. Red means you're at risk — update your current AR in Settings."),

        TutorialStep(tab: 0, anchorID: "gauge",
                     title: "Offer grade",
                     body: "The big number is $/mi, color-coded by your thresholds. Fill in Pay and Miles below and it updates live before you decide."),

        TutorialStep(tab: 0, anchorID: "restaurant-zone",
                     title: "Restaurant & Zone",
                     body: "Type the restaurant name — Meter autocompletes from your history. After a few pickups, the gauge shows that spot's average wait time above."),

        TutorialStep(tab: 0, anchorID: "input-grid",
                     title: "Pay · Miles · Mins",
                     body: "Three tappable input cells. Fill all three to unlock the NET/HR chip showing your projected hourly rate for this offer."),

        TutorialStep(tab: 0, anchorID: "accept-decline",
                     title: "Accept or Decline",
                     body: "Accept logs the order and shows it above with a glowing cyan border — you can track up to 3 simultaneous orders. Both decisions count toward your rolling AR."),

        TutorialStep(tab: 0, anchorID: "missed-row",
                     title: "Missed an offer?",
                     body: "Tap +dec or +acc to log an offer you saw but couldn't enter in time. Keeps your AR tracking accurate."),

        TutorialStep(tab: 0, anchorID: "shift-clock",
                     title: "Shift clock",
                     body: "Enter your odometer when you clock in — the card glows cyan while your shift is active. Clock out with the ending odo to capture your tax-ready mileage delta."),

        // ── Log ─────────────────────────────────────────────────────────────
        TutorialStep(tab: 1, anchorID: "log-header",
                     title: "Your log",
                     body: "All offers, newest first. Swipe left to delete — a recovery row appears at the top if you need it back. Tap the pencil icon to edit any field."),

        TutorialStep(tab: 1, anchorID: "log-final-pay",
                     title: "Final pay",
                     body: "Enter the actual DoorDash payout after delivery. If it's higher than the offer amount, the difference is a hidden tip — Stats tracks those totals."),

        // ── Spots ────────────────────────────────────────────────────────────
        TutorialStep(tab: 2, anchorID: "spots-filter",
                     title: "Filter by daypart",
                     body: "Some spots are fast at lunch and slow at dinner. Filter to see wait-time rankings for the part of day you're dashing right now."),

        TutorialStep(tab: 2, anchorID: "spots-list",
                     title: "Wait rankings",
                     body: "Green = fast, amber = OK, red = slow. Tap Add to save parking or entry notes. Notes appear on the offer gauge the next time you see that restaurant."),

        // ── Stats ────────────────────────────────────────────────────────────
        TutorialStep(tab: 3, anchorID: "stats-scope",
                     title: "Today vs. all time",
                     body: "Today shows your current shift only. All time shows lifetime totals, your IRS mileage write-off estimate, and total hidden tips uncovered."),

        TutorialStep(tab: 3, anchorID: "stats-real-hr",
                     title: "Real $/hr",
                     body: "Net pay ÷ total shift hours, including idle time between orders. Your honest hourly rate — not just when orders are active."),

        // ── Settings ─────────────────────────────────────────────────────────
        TutorialStep(tab: 4, anchorID: "settings-thresholds",
                     title: "Thresholds",
                     body: "Set your green/OK/floor $/mi targets. Every color in the gauge is driven by these — tune them to match your market and car costs."),

        TutorialStep(tab: 4, anchorID: "settings-ar",
                     title: "Your current AR",
                     body: "Find your actual acceptance rate under Ratings in the DoorDash app and enter it here. Tap Save — Meter uses it to calibrate the rolling AR estimate."),
    ]

    var currentStep: TutorialStep? {
        guard stepIndex < steps.count else { return nil }
        return steps[stepIndex]
    }

    var isLastStep: Bool { stepIndex >= steps.count - 1 }
    var progress: String { "\(stepIndex + 1) of \(steps.count)" }

    func start() {
        stepIndex = 0
        anchors   = [:]
        isActive  = true
    }

    func advance() {
        if isLastStep { dismiss() } else { stepIndex += 1 }
    }

    func back() {
        if stepIndex > 0 { stepIndex -= 1 }
    }

    func dismiss() {
        isActive  = false
        stepIndex = 0
    }
}

// MARK: – Anchor preference key

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: – View modifier

extension View {
    func tutorialAnchor(_ id: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: TutorialAnchorKey.self,
                    value: [id: geo.frame(in: .named("tutorialSpace"))]
                )
            }
        )
    }
}
