import SwiftUI

struct TutorialOverlay: View {
    @ObservedObject var tutorial: TutorialManager
    let step: TutorialStep

    private let spotPad: CGFloat = 10
    private let tipWidth: CGFloat = 300

    private var spot: CGRect {
        guard let raw = tutorial.anchors[step.anchorID], raw != .zero else { return .zero }
        return raw.insetBy(dx: -spotPad, dy: -spotPad)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark overlay with spotlight cutout
                overlayMask

                // Tap outside spotlight to advance (convenience)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tutorial.advance() }

                // Tooltip callout
                if spot != .zero {
                    callout(in: geo.size)
                } else {
                    // No anchor found — centered card fallback
                    centeredCard(in: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: step.anchorID)
        .animation(.easeInOut(duration: 0.25), value: tutorial.stepIndex)
    }

    // MARK: – Spotlight mask

    private var overlayMask: some View {
        Color.black.opacity(0.72)
            .mask(
                ZStack {
                    Rectangle()
                    if spot != .zero {
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: spot.width, height: spot.height)
                            .position(x: spot.midX, y: spot.midY)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            )
    }

    // MARK: – Callout

    private func callout(in size: CGSize) -> some View {
        let showAbove = spot.midY > size.height * 0.55
        let arrowX    = clamp(spot.midX, lo: 24 + 10, hi: size.width - 24 - 10)
        let cardX     = clamp(spot.midX, lo: 24 + tipWidth / 2, hi: size.width - 24 - tipWidth / 2)

        let cardY: CGFloat = showAbove
            ? spot.minY - 12 - cardHeight - 10     // above spotlight
            : spot.maxY + 12 + cardHeight / 2 + 10  // below spotlight

        return ZStack {
            // Arrow tip
            ArrowTip(pointsUp: !showAbove)
                .fill(Color.mElev)
                .frame(width: 18, height: 10)
                .position(
                    x: arrowX,
                    y: showAbove ? spot.minY - 12 : spot.maxY + 12
                )

            // Card
            tooltipCard
                .frame(width: tipWidth)
                .position(x: cardX, y: cardY)
        }
    }

    // Rough height estimate for positioning (avoids GeometryReader nesting)
    private var cardHeight: CGFloat { 160 }

    private func centeredCard(in size: CGSize) -> some View {
        tooltipCard
            .frame(width: tipWidth)
            .position(x: size.width / 2, y: size.height / 2)
    }

    // MARK: – Tooltip card

    private var tooltipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Progress
            HStack {
                Text(tutorial.progress)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.mFaint)
                Spacer()
                Button {
                    tutorial.dismiss()
                } label: {
                    Text("Skip")
                        .font(.system(size: 12))
                        .foregroundColor(.mFaint)
                }
            }

            // Progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.mLine).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(Color.mAccent)
                        .frame(width: g.size.width * CGFloat(tutorial.stepIndex + 1) / CGFloat(tutorial.steps.count),
                               height: 3)
                }
            }
            .frame(height: 3)

            // Content
            Text(step.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mText)

            Text(step.body)
                .font(.system(size: 13))
                .foregroundColor(.mMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Navigation
            HStack {
                if tutorial.stepIndex > 0 {
                    Button("← Back") { tutorial.stepIndex -= 1 }
                        .font(.system(size: 13))
                        .foregroundColor(.mFaint)
                }
                Spacer()
                Button {
                    withAnimation { tutorial.advance() }
                } label: {
                    Text(tutorial.isLastStep ? "Done ✓" : "Next →")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(tutorial.isLastStep ? Color.mGreen : Color.mAccent)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.mElev)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 4)
    }

    // MARK: – Helpers

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}

// MARK: – Arrow tip shape

struct ArrowTip: Shape {
    let pointsUp: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointsUp {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}
