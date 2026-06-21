import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: AppState
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            Group {
                if store.offers.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.offers.reversed()) { offer in
                            OfferRow(offer: offer, now: now)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.mBg)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onReceive(ticker) { _ in now = Date() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 44))
                .foregroundColor(.mFaint)
            Text("No offers logged yet")
                .font(.system(size: 16))
                .foregroundColor(.mMuted)
            Text("Log offers in the Decide tab to see them here")
                .font(.system(size: 13))
                .foregroundColor(.mFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Single offer row

struct OfferRow: View {
    @EnvironmentObject var store: AppState
    var offer: Offer
    var now: Date

    @State private var finalPayStr:    String = ""
    @State private var manualWaitStr:  String = ""
    @State private var initialized:    Bool   = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topRow
            if !offer.missed { detailLine }
            if offer.decision == "accept" && !offer.missed {
                finalPayRow
                pickupTimerRow
            }
        }
        .padding(12)
        .background(Color.mSurface)
        .cornerRadius(10)
        .onAppear {
            guard !initialized else { return }
            initialized   = true
            finalPayStr   = offer.finalPay.map { String(format: "%.2f", $0) } ?? ""
            manualWaitStr = offer.wait.map     { String(format: "%.0f", $0) } ?? ""
        }
    }

    // MARK: – Top row

    private var topRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Badge(
                text: offer.missed ? "MISS" : offer.decision == "accept" ? "ACC" : "DEC",
                color: offer.missed ? .mFaint : offer.decision == "accept" ? .mGreen : .mRed
            )

            if offer.missed {
                Text("missed · counts toward AR only")
                    .font(.system(size: 13))
                    .foregroundColor(.mFaint)
            } else {
                if let p = offer.pay {
                    Text(String(format: "$%.2f", p))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.mText)
                }
                if !offer.merchant.isEmpty {
                    Text(offer.merchant)
                        .font(.system(size: 13))
                        .foregroundColor(.mMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let dpm = offer.dpm, dpm.isFinite, !offer.missed {
                let lv = Calculations.level(dpm: dpm, pay: offer.pay ?? 0, s: store.settings)
                Text(String(format: "$%.2f/mi", dpm))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(levelColor(lv))
            }

            Text(offer.ts, style: .time)
                .font(.system(size: 12))
                .foregroundColor(.mFaint)

            Button {
                store.deleteOffer(id: offer.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mFaint)
                    .padding(4)
            }
        }
    }

    // MARK: – Detail line

    private var detailLine: some View {
        HStack(spacing: 10) {
            if let m = offer.miles {
                Text(String(format: "%.1f mi", m))
                    .font(.system(size: 12)).foregroundColor(.mFaint)
            }
            if let mn = offer.mins {
                Text(String(format: "%.0f min", mn))
                    .font(.system(size: 12)).foregroundColor(.mFaint)
            }
            if !offer.zone.isEmpty {
                Text(offer.zone)
                    .font(.system(size: 12)).foregroundColor(.mFaint)
            }
        }
    }

    // MARK: – Final pay row

    private var finalPayRow: some View {
        HStack(spacing: 8) {
            Text("Final $")
                .font(.system(size: 13))
                .foregroundColor(.mMuted)
            TextField("amount", text: $finalPayStr)
                .keyboardType(.decimalPad)
                .font(.system(size: 13))
                .foregroundColor(.mText)
                .frame(width: 70)
                .onSubmit { saveFinalPay() }

            Button("Save") { saveFinalPay() }
                .font(.system(size: 12))
                .foregroundColor(.mAccent)

            if let fp = offer.finalPay, let op = offer.pay, fp > op {
                Text(String(format: "+$%.2f hidden", fp - op))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.mGreen)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mGreen.opacity(0.12))
                    .cornerRadius(6)
            }
        }
    }

    private func saveFinalPay() {
        var updated = offer
        updated.finalPay = Double(finalPayStr)
        store.updateOffer(updated)
    }

    // MARK: – Pickup timer

    // 0 = nothing  1 = driving  2 = waiting  3 = done
    private var timerState: Int {
        if offer.wait != nil || (offer.driveMin != nil && offer.waitStart == nil) { return 3 }
        if offer.waitStart  != nil { return 2 }
        if offer.driveStart != nil { return 1 }
        return 0
    }

    @ViewBuilder
    private var pickupTimerRow: some View {
        HStack(spacing: 10) {
            switch timerState {
            case 0:
                Button {
                    var u = offer; u.driveStart = Date()
                    store.updateOffer(u)
                } label: {
                    Label("Start drive", systemImage: "car.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.mAccent)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.mAccent.opacity(0.1)).cornerRadius(7)
                }

                HStack(spacing: 4) {
                    TextField("min", text: $manualWaitStr)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 12))
                        .foregroundColor(.mText)
                        .frame(width: 40)
                    Text("wait min")
                        .font(.system(size: 12)).foregroundColor(.mFaint)
                    Button("Save") {
                        if let w = Double(manualWaitStr) {
                            var u = offer; u.wait = w
                            store.updateOffer(u)
                        }
                    }
                    .font(.system(size: 12)).foregroundColor(.mAccent)
                }

            case 1:
                if let ds = offer.driveStart {
                    Text("🚗 " + fmtDuration(now.timeIntervalSince(ds)))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.mAccent)
                }
                Button("At store") {
                    var u = offer
                    if let ds = u.driveStart {
                        u.driveMin = Date().timeIntervalSince(ds) / 60
                    }
                    u.waitStart = Date()
                    store.updateOffer(u)
                }
                .font(.system(size: 12))
                .foregroundColor(.mAmber)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.mAmber.opacity(0.1)).cornerRadius(7)

            case 2:
                if let dm = offer.driveMin {
                    Text(String(format: "🚗 %.1fm", dm))
                        .font(.system(size: 12)).foregroundColor(.mMuted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.mElev).cornerRadius(6)
                }
                if let ws = offer.waitStart {
                    Text("⏱ " + fmtDuration(now.timeIntervalSince(ws)))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.mOrange)
                }
                Button("Got food") {
                    var u = offer
                    if let ws = u.waitStart {
                        u.wait = Date().timeIntervalSince(ws) / 60
                    }
                    store.updateOffer(u)
                }
                .font(.system(size: 12))
                .foregroundColor(.mGreen)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.mGreen.opacity(0.1)).cornerRadius(7)

            default:
                if let dm = offer.driveMin {
                    Text(String(format: "🚗 %.1fm", dm))
                        .font(.system(size: 12)).foregroundColor(.mMuted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.mElev).cornerRadius(6)
                }
                if let w = offer.wait {
                    let color: Color = w >= store.settings.slowWait ? .mOrange : .mGreen
                    Text(String(format: "⏱ %.0fm wait", w))
                        .font(.system(size: 12)).foregroundColor(color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.1)).cornerRadius(6)
                }
            }
        }
    }
}
