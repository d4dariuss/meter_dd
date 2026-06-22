import SwiftUI

// MARK: – Data

private struct TutorialSlide {
    let icon:      String
    let iconColor: Color
    let title:     String
    let body:      String
    let tab:       String?
}

private let slides: [TutorialSlide] = [
    TutorialSlide(
        icon: "bolt.circle.fill", iconColor: .mAccent,
        title: "Welcome to Meter",
        body:  "Your DoorDash co-pilot. See each offer's real value in seconds, track what you actually earn, and learn which restaurants waste your time.",
        tab:   nil
    ),
    TutorialSlide(
        icon: "gauge.high", iconColor: .mGreen,
        title: "Evaluate offers instantly",
        body:  "Enter payout, miles, and minutes into the three input cells. The gauge shows $/mi color-coded by your thresholds. Accept and the order appears with a glowing border — track up to 3 at once.",
        tab:   "Decide tab"
    ),
    TutorialSlide(
        icon: "clock.badge.checkmark.fill", iconColor: .mAmber,
        title: "Track your shift",
        body:  "Clock in with your odometer — the shift card glows cyan while you're active. Clock out with the ending reading for a tax-ready mileage delta. The today strip shows your real hourly rate.",
        tab:   "Decide tab"
    ),
    TutorialSlide(
        icon: "car.fill", iconColor: .mAccent,
        title: "Time your pickups",
        body:  "In the Log tab, tap Start drive when you leave, At store when you arrive, Got food when you pick up. Meter tracks how long each restaurant actually takes so you can avoid slow spots.",
        tab:   "Log tab"
    ),
    TutorialSlide(
        icon: "mappin.circle.fill", iconColor: .mOrange,
        title: "Know your spots",
        body:  "Restaurants rank by median wait time, built automatically from your pickup timers. Green = fast, red = slow. Filter by lunch, dinner, or late night to compare the same daypart.",
        tab:   "Spots tab"
    ),
    TutorialSlide(
        icon: "chart.bar.fill", iconColor: .mAccent,
        title: "See your real numbers",
        body:  "Today vs. all-time earnings, net after mileage costs, active-order $/hr vs. real $/hr across your full shift. Enter final pay in Log to uncover hidden tips.",
        tab:   "Stats tab"
    ),
    TutorialSlide(
        icon: "location.fill", iconColor: .mGreen,
        title: "GPS tracking",
        body:  "The pulsing status dot on the GPS pill shows tracking is live. Grant 'Always' location so it keeps running while you navigate in another app. Use your odometer log as the official tax record — GPS is a cross-check.",
        tab:   "Decide tab"
    ),
]

// MARK: – Main view

struct TutorialView: View {
    let onDismiss: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            Color.mBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button row
                HStack {
                    Spacer()
                    if page < slides.count - 1 {
                        Button("Skip") { onDismiss() }
                            .font(.system(size: 15))
                            .foregroundColor(.mFaint)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 24)

                // Slides (swipeable)
                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        SlideCard(slide: slides[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.mAccent : Color.mLine)
                            .frame(width: i == page ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 24)

                // Next / Get Started button
                Button {
                    if page < slides.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    } else {
                        onDismiss()
                    }
                } label: {
                    Text(page < slides.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.mAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: – Slide card

private struct SlideCard: View {
    let slide: TutorialSlide

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: slide.icon)
                .font(.system(size: 72))
                .foregroundColor(slide.iconColor)
                .padding(.bottom, 32)

            // Tab pill
            if let tab = slide.tab {
                Text(tab.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(slide.iconColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(slide.iconColor.opacity(0.12))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(slide.iconColor.opacity(0.35), lineWidth: 0.5))
                    .padding(.bottom, 16)
            }

            // Title
            Text(slide.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.mText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            // Body
            Text(slide.body)
                .font(.system(size: 16))
                .foregroundColor(.mMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
