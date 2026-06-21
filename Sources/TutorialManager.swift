import SwiftUI

// MARK: – Step definition

struct TutorialStep {
    let tab:       Int     // 0=Decide 1=Log 2=Spots 3=Stats 4=Settings
    let anchorID:  String  // matches .tutorialAnchor("id") on a real view
    let title:     String
    let body:      String
}

// MARK: – Manager

class TutorialManager: ObservableObject {
    @Published var isActive:   Bool = false
    @Published var stepIndex:  Int  = 0
    @Published var anchors:    [String: CGRect] = [:]

    static let shared = TutorialManager()   // convenience; inject via environmentObject

    let steps: [TutorialStep] = [

        // ── Decide tab ──────────────────────────────────────────────────────
        TutorialStep(tab: 0, anchorID: "ar-header",
                     title: "Rolling acceptance rate",
                     body: "Estimated from your last 100 offers, seeded by your current DoorDash AR setting. Green = Platinum-safe. Red = at risk."),

        TutorialStep(tab: 0, anchorID: "gauge",
                     title: "Offer grade",
                     body: "The big number is $/mi — green is strong, red is skip. Fill in pay and miles below to see it update live before you decide."),

        TutorialStep(tab: 0, anchorID: "restaurant-zone",
                     title: "Restaurant & zone",
                     body: "Type the name before you accept. After a few pickups Meter shows that restaurant's average wait time and your saved notes right here, in the gauge."),

        TutorialStep(tab: 0, anchorID: "input-grid",
                     title: "Enter the offer",
                     body: "Pay in dollars, miles to pickup, estimated minutes (optional — minutes unlock the NET/HR chip showing how much you earn per active hour)."),

        TutorialStep(tab: 0, anchorID: "accept-decline",
                     title: "Accept or Decline",
                     body: "Accept logs the offer and starts your drive timer automatically. Decline logs a rejection. Both count toward your rolling acceptance rate."),

        TutorialStep(tab: 0, anchorID: "missed-row",
                     title: "Log a missed offer",
                     body: "Saw an offer but didn't log it in time? Tap +dec or +acc to add it. Keeps your AR tracking honest without inventing offer data."),

        TutorialStep(tab: 0, anchorID: "shift-clock",
                     title: "Shift clock & odometer",
                     body: "Clock In when you start dashing and enter your odometer reading. Clock Out with the ending number — that delta is your tax-ready mileage record for the day."),

        // ── Log tab ─────────────────────────────────────────────────────────
        TutorialStep(tab: 1, anchorID: "log-header",
                     title: "Your offer log",
                     body: "Every offer lives here, newest first. After accepting, tap 'Start drive' when you leave, 'At store' when you arrive, 'Got food' when you pick up — this builds your restaurant wait rankings automatically."),

        TutorialStep(tab: 1, anchorID: "log-final-pay",
                     title: "Enter final pay",
                     body: "After delivery, type the actual payout from the DoorDash app. If it's higher than the offer, that's a hidden tip — the Stats tab tracks how often this happens and how much extra you're earning."),

        // ── Spots tab ────────────────────────────────────────────────────────
        TutorialStep(tab: 2, anchorID: "spots-filter",
                     title: "Daypart filter",
                     body: "Some spots are fast at lunch but a disaster at dinner. Filter here to compare wait times for the time of day you're actually dashing right now."),

        TutorialStep(tab: 2, anchorID: "spots-list",
                     title: "Restaurant wait rankings",
                     body: "Sorted by median wait time — green is fast, red is slow. Tap 'Add' on any row to save a note (parking, entrance, anything useful). Notes appear in the gauge before you accept next time."),

        // ── Stats tab ────────────────────────────────────────────────────────
        TutorialStep(tab: 3, anchorID: "stats-scope",
                     title: "Today vs. all time",
                     body: "Today shows your current shift performance. All time includes your lifetime totals, tax write-off amount, and hidden tip totals."),

        TutorialStep(tab: 3, anchorID: "stats-real-hr",
                     title: "Real $/hr — your honest number",
                     body: "Net pay divided by total shift hours, including dead time between orders. If this trails your target, you're losing too much time waiting for offers."),

        // ── Settings tab ─────────────────────────────────────────────────────
        TutorialStep(tab: 4, anchorID: "settings-thresholds",
                     title: "Decision thresholds",
                     body: "Strong ≥ is your green target. OK ≥ is acceptable. Floor is the bare minimum. These drive every color in the gauge — tune them to match your market."),

        TutorialStep(tab: 4, anchorID: "settings-ar",
                     title: "Your current DoorDash AR",
                     body: "Find your actual AR under Ratings in the DoorDash app and enter it here. This seeds the rolling estimate so it's accurate from your very first offer, not just after 100."),
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
    /// Tag this view so the tutorial can spotlight it by ID.
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
