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
                     body: "Estimated from your last 100 offers. Green means you're Platinum-safe. Red means you're at risk of losing it."),

        TutorialStep(tab: 0, anchorID: "gauge",
                     title: "Offer grade",
                     body: "The big number is $/mi. Fill in pay and miles below to see it update live before you decide."),

        TutorialStep(tab: 0, anchorID: "restaurant-zone",
                     title: "Restaurant",
                     body: "Type the name before you accept. After a few pickups, Meter shows that spot's average wait time right here."),

        TutorialStep(tab: 0, anchorID: "input-grid",
                     title: "Enter the offer",
                     body: "Pay in dollars, miles to pickup. Adding minutes unlocks a NET/HR chip showing your hourly rate."),

        TutorialStep(tab: 0, anchorID: "accept-decline",
                     title: "Accept or Decline",
                     body: "Accept starts a 4-leg delivery timer automatically. Decline logs the skip. Both count toward your rolling AR."),

        TutorialStep(tab: 0, anchorID: "missed-row",
                     title: "Missed an offer?",
                     body: "Tap +dec or +acc to log an offer you saw but couldn't enter in time. Keeps your AR tracking honest."),

        TutorialStep(tab: 0, anchorID: "shift-clock",
                     title: "Shift clock",
                     body: "Enter your odometer when you clock in and out. That delta is your official tax mileage record for the day."),

        // ── Log ─────────────────────────────────────────────────────────────
        TutorialStep(tab: 1, anchorID: "log-header",
                     title: "Your log",
                     body: "All offers, newest first. Swipe left to delete — if you do it by accident, a recovery row appears at the top. Tap ✏ to edit any field after delivery."),

        TutorialStep(tab: 1, anchorID: "log-final-pay",
                     title: "Final pay",
                     body: "Enter the actual payout from DoorDash. If it's higher than the offer, that's a hidden tip — Stats tracks the totals."),

        // ── Spots ────────────────────────────────────────────────────────────
        TutorialStep(tab: 2, anchorID: "spots-filter",
                     title: "Filter by daypart",
                     body: "Some spots are fast at lunch and slow at dinner. Filter here to see wait times for the time of day you're dashing now."),

        TutorialStep(tab: 2, anchorID: "spots-list",
                     title: "Wait rankings",
                     body: "Green = fast, red = slow. Tap Add to save a note about parking or entry. Notes show in the gauge before you accept next time."),

        // ── Stats ────────────────────────────────────────────────────────────
        TutorialStep(tab: 3, anchorID: "stats-scope",
                     title: "Today vs. all time",
                     body: "Today shows your current shift. All time includes lifetime totals, tax write-off amount, and hidden tip totals."),

        TutorialStep(tab: 3, anchorID: "stats-real-hr",
                     title: "Real $/hr",
                     body: "Net pay ÷ total shift hours, including dead time between orders. Your honest rate — not just when orders are active."),

        // ── Settings ─────────────────────────────────────────────────────────
        TutorialStep(tab: 4, anchorID: "settings-thresholds",
                     title: "Thresholds",
                     body: "Set your green/OK/floor $/mi targets. These drive every color in the gauge — tune them to match your market."),

        TutorialStep(tab: 4, anchorID: "settings-ar",
                     title: "Your current AR",
                     body: "Find your actual AR under Ratings in the DoorDash app and enter it here. Tap Save when done."),
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
