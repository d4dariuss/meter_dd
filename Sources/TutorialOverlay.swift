import SwiftUI

struct TutorialOverlay: View {
    @ObservedObject var tutorial: TutorialManager
    let step: TutorialStep

    private let calloutWidth: CGFloat = 288
    private let calloutEstH:  CGFloat = 158    // estimated height for Y positioning
    private let ringPad:      CGFloat = 6
    private let arrowH:       CGFloat = 10

    private var anchor: CGRect {
        tutorial.anchors[step.anchorID] ?? .zero
    }

    var body: some View {
        // Use UIScreen bounds to avoid a GeometryReader that would swallow touches.
        // The underlying app stays fully interactive — only the callout card
        // captures taps (for its buttons). Everything else passes through.
        let size = UIScreen.main.bounds.size

        ZStack {
            // Transparent, non-blocking backdrop — MUST come first
            Color.clear.allowsHitTesting(false)

            if anchor != .zero {
                highlightRing          // .allowsHitTesting(false) inside
                calloutGroup(in: size) // only the card itself intercepts taps
            } else {
                fallbackCard(in: size)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.22), value: step.anchorID)
        .animation(.easeInOut(duration: 0.22), value: tutorial.stepIndex)
    }

    // MARK: – Accent ring around the anchored element

    private var highlightRing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.mAccent.opacity(0.08))
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.mAccent, lineWidth: 2)
        }
        .frame(
            width:  anchor.width  + ringPad * 2,
            height: anchor.height + ringPad * 2
        )
        .shadow(color: Color.mAccent.opacity(0.45), radius: 8)
        .position(x: anchor.midX, y: anchor.midY)
        .allowsHitTesting(false)    // ring itself never blocks the UI it's highlighting
    }

    // MARK: – Arrow + callout bubble

    @ViewBuilder
    private func calloutGroup(in size: CGSize) -> some View {
        // Put callout above anchor when anchor is in the lower half of screen
        let showAbove = anchor.midY > size.height * 0.50

        // Callout center X: align with anchor, clamped to screen edges
        let calloutX = (anchor.midX)
            .clamped(to: calloutWidth / 2 + 16 ... size.width - calloutWidth / 2 - 16)

        // Arrow X: try to point at anchor midX, keep inside callout bounds
        let arrowX = (anchor.midX)
            .clamped(to: calloutX - calloutWidth / 2 + 18 ... calloutX + calloutWidth / 2 - 18)

        // Arrow Y: just outside the highlight ring
        let arrowY: CGFloat = showAbove
            ? anchor.minY - ringPad - arrowH / 2 - 2
            : anchor.maxY + ringPad + arrowH / 2 + 2

        // Callout center Y: clear of ring + arrow, clamped to remain on screen
        var calloutY: CGFloat = showAbove
            ? anchor.minY - ringPad - arrowH - 8 - calloutEstH / 2
            : anchor.maxY + ringPad + arrowH + 8 + calloutEstH / 2
        calloutY = calloutY.clamped(to: calloutEstH / 2 + 54 ... size.height - calloutEstH / 2 - 88)

        // Arrow triangle (non-interactive)
        ArrowTip(pointsUp: !showAbove)
            .fill(Color.mElev)
            .frame(width: 22, height: arrowH)
            .position(x: arrowX, y: arrowY)
            .allowsHitTesting(false)

        // Callout bubble (interactive — buttons inside work normally)
        calloutCard
            .frame(width: calloutWidth)
            .background(Color.mElev)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 4)
            .position(x: calloutX, y: calloutY)
    }

    private func fallbackCard(in size: CGSize) -> some View {
        calloutCard
            .frame(width: calloutWidth)
            .background(Color.mElev)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 4)
            .position(x: size.width / 2, y: size.height * 0.46)
    }

    // MARK: – Callout card content

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title + step counter
            HStack(alignment: .top) {
                Text(step.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.mText)
                Spacer()
                Text(tutorial.progress)
                    .font(.system(size: 11))
                    .foregroundColor(.mFaint)
            }

            // Body
            Text(step.body)
                .font(.system(size: 13))
                .foregroundColor(.mMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.mLine).frame(height: 2)
                    RoundedRectangle(cornerRadius: 2).fill(Color.mAccent)
                        .frame(
                            width: g.size.width * CGFloat(tutorial.stepIndex + 1)
                                   / CGFloat(max(tutorial.steps.count, 1)),
                            height: 2
                        )
                        .animation(.easeInOut(duration: 0.22), value: tutorial.stepIndex)
                }
            }
            .frame(height: 2)

            // Navigation buttons
            HStack(spacing: 8) {
                Button("Skip") { tutorial.dismiss() }
                    .font(.system(size: 12))
                    .foregroundColor(.mFaint)

                Spacer()

                if tutorial.stepIndex > 0 {
                    Button("← Back") { tutorial.back() }
                        .font(.system(size: 13))
                        .foregroundColor(.mMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.mSurface).cornerRadius(7)
                }

                Button {
                    withAnimation { tutorial.advance() }
                } label: {
                    Text(tutorial.isLastStep ? "Done ✓" : "Next →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(tutorial.isLastStep ? Color.mGreen : Color.mAccent)
                        .cornerRadius(7)
                }
            }
        }
        .padding(14)
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

// MARK: – Clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
