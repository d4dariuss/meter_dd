import SwiftUI

struct DecideView: View {
    @EnvironmentObject var store:   AppState
    @EnvironmentObject var tracker: LocationTracker

    @State private var payStr:    String = ""
    @State private var miStr:     String = ""
    @State private var minStr:    String = ""
    @State private var merchant:  String = ""
    @State private var zone:      String = ""
    @State private var odoStr:    String = ""
    @State private var now:       Date   = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: – Derived values

    private var pay:   Double? { Double(payStr)  }
    private var miles: Double? { Double(miStr)   }
    private var mins:  Double? { Double(minStr)  }

    private var dpm: Double {
        guard let p = pay, let m = miles, m > 0 else { return .nan }
        return p / m
    }

    private var lv: String {
        guard let p = pay, let m = miles else { return "none" }
        return Calculations.level(dpm: Calculations.dpm(pay: p, miles: m), pay: p, s: store.settings)
    }

    private var netOff: Double? {
        guard let p = pay, let m = miles else { return nil }
        return Calculations.netOffer(pay: p, miles: m, cpm: store.settings.cpm)
    }

    private var nph: Double? {
        guard let p = pay, let m = miles, let mn = mins else { return nil }
        return Calculations.netHr(pay: p, miles: m, mins: mn, cpm: store.settings.cpm)
    }

    private var canDecide: Bool { pay != nil && miles != nil }

    private var merchantWait: Double? {
        let key = merchant.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return nil }
        let stats = Calculations.merchantStats(offers: store.data.offers) {
            $0.merchant.lowercased() == key
        }
        guard let med = stats.first?.medWait, med.isFinite else { return nil }
        return med
    }

    private var todayAgg: AggResult {
        Calculations.agg(offers: store.todayOffers, cpm: store.settings.cpm)
    }

    // MARK: – Body

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // GPS pill
                HStack {
                    Spacer()
                    GpsPill()
                    Spacer()
                }
                .padding(.top, 8)

                // Backup banner
                if store.needsBackup { backupBanner }

                // AR header
                arHeader

                // Gauge
                gaugeCard

                // Input
                inputCard

                // Accept / Decline
                actionButtons

                // Undo + Missed
                undoMissedRow

                // Shift clock
                shiftClockCard

                // Today strip
                todayStrip

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.mBg.ignoresSafeArea())
        .onReceive(ticker) { _ in now = Date() }
    }

    // MARK: – AR header

    private var arHeader: some View {
        let ar = Calculations.estAR(offers: store.offers, currentAR: store.settings.currentAR)
        let arColor: Color = ar.valid && ar.pct >= store.settings.arFloor ? .mGreen : .mRed
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meter")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.mText)
                Text("offer caller")
                    .font(.system(size: 12))
                    .foregroundColor(.mFaint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Text("ROLLING AR · EST")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.mFaint)
                    Text(ar.valid ? String(format: "%.0f%%", ar.pct) : "—")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(arColor)
                }
                if ar.valid {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.mLine)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(arColor)
                                .frame(width: geo.size.width * min(ar.pct / 100, 1), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 130)
                    Text(ar.pct >= store.settings.arFloor ? "Platinum safe" : "Below floor")
                        .font(.system(size: 10))
                        .foregroundColor(.mFaint)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: – Backup banner

    private var backupBanner: some View {
        Button { shareJSON() } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                Text("Back up: \(store.offers.count - store.data.lastExportLen) offers since last export")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.mAmber)
            .padding(12)
            .background(Color.mAmber.opacity(0.12))
            .cornerRadius(8)
        }
    }

    // MARK: – Gauge card

    private var gaugeCard: some View {
        Card {
            VStack(spacing: 14) {
                Text(dpm.isFinite ? String(format: "$%.2f/mi", dpm) : "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(levelColor(lv))

                Text(verdict)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(levelColor(lv))

                HStack(spacing: 10) {
                    if let n = nph {
                        gaugeChip(label: "NET/HR",
                                  value: String(format: "$%.0f", n),
                                  color: n >= store.settings.hrTarget ? .mGreen : .mRed)
                    }
                    if let net = netOff {
                        gaugeChip(label: "NET/OFFER",
                                  value: String(format: "$%.2f", net),
                                  color: net >= 0 ? .mText : .mRed)
                    }
                    if let w = merchantWait {
                        gaugeChip(label: "WAIT",
                                  value: String(format: "~%.0fm", w),
                                  color: w >= store.settings.slowWait ? .mOrange : .mGreen)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    private func gaugeChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.mFaint)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mElev)
        .cornerRadius(8)
    }

    private var verdict: String {
        switch lv {
        case "green":  return "STRONG"
        case "amber":  return "OK"
        case "orange": return "MARGINAL"
        case "red":    return "SKIP"
        default:       return "ENTER OFFER"
        }
    }

    // MARK: – Input card

    private var inputCard: some View {
        Card {
            // Restaurant
            HStack {
                Text("Restaurant")
                    .font(.system(size: 14))
                    .foregroundColor(.mMuted)
                    .frame(width: 90, alignment: .leading)
                TextField("name", text: $merchant)
                    .font(.system(size: 15))
                    .foregroundColor(.mText)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            MLine()

            // Zone
            HStack {
                Text("Zone")
                    .font(.system(size: 14))
                    .foregroundColor(.mMuted)
                    .frame(width: 90, alignment: .leading)
                TextField("area / market", text: $zone)
                    .font(.system(size: 15))
                    .foregroundColor(.mText)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            // Recent merchant chips
            if !store.recentMerchants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.recentMerchants, id: \.self) { m in
                            Button(m) {
                                merchant = m
                                if let prev = store.offers.last(where: { $0.merchant == m }) {
                                    zone = prev.zone
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.mAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.mElev)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            MLine()

            // Pay / Miles / Mins
            HStack(spacing: 0) {
                inputCell(label: "Pay $",  text: $payStr)
                Color.mLine.frame(width: 1)
                inputCell(label: "Miles",  text: $miStr)
                Color.mLine.frame(width: 1)
                inputCell(label: "Mins",   text: $minStr)
            }
            .frame(height: 68)
        }
    }

    private func inputCell(label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.mFaint)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.mText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Action buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { logOffer("decline") } label: {
                Text("Decline")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(canDecide ? .mRed : .mFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mSurface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(canDecide ? Color.mRed.opacity(0.5) : Color.mLine, lineWidth: 1)
                    )
            }
            .disabled(!canDecide)

            Button { logOffer("accept") } label: {
                Text("Accept")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(canDecide ? .white : .mFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canDecide ? levelColor(lv) : Color.mElev)
                    .cornerRadius(10)
            }
            .disabled(!canDecide)
        }
    }

    // MARK: – Undo + Missed

    private var undoMissedRow: some View {
        HStack(spacing: 10) {
            Button {
                store.undoLast()
            } label: {
                Label("Undo last", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 13))
                    .foregroundColor(.mMuted)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.mSurface)
                    .cornerRadius(8)
            }

            Spacer()

            Text("Missed?")
                .font(.system(size: 13))
                .foregroundColor(.mFaint)

            Button("+ dec") { logMissed("decline") }
                .font(.system(size: 13))
                .foregroundColor(.mRed)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Color.mSurface).cornerRadius(8)

            Button("+ acc") { logMissed("accept") }
                .font(.system(size: 13))
                .foregroundColor(.mGreen)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Color.mSurface).cornerRadius(8)
        }
    }

    // MARK: – Shift clock

    private var shiftClockCard: some View {
        Card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHIFT CLOCK")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.mFaint)

                    if let start = store.activeShift {
                        Text(fmtDuration(now.timeIntervalSince(start)))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.mText)
                        Text("since \(start, style: .time)")
                            .font(.system(size: 12))
                            .foregroundColor(.mMuted)
                    } else {
                        Text("Not clocked in")
                            .font(.system(size: 15))
                            .foregroundColor(.mMuted)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(store.activeShift == nil ? "Clock In" : "Clock Out") {
                        if store.activeShift == nil {
                            store.clockIn(odo: Double(odoStr))
                        } else {
                            store.clockOut(odo: Double(odoStr))
                            odoStr = ""
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(store.activeShift == nil ? .mAccent : .mOrange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background((store.activeShift == nil ? Color.mAccent : Color.mOrange).opacity(0.15))
                    .cornerRadius(8)

                    HStack(spacing: 6) {
                        Text("Odo:")
                            .font(.system(size: 12))
                            .foregroundColor(.mFaint)
                        TextField("mi", text: $odoStr)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 13))
                            .foregroundColor(.mText)
                            .frame(width: 70)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: – Today strip

    private var todayStrip: some View {
        let a   = todayAgg
        let rhr = store.realHr(todayOnly: true)
        return HStack(spacing: 0) {
            stripItem(label: "orders",    value: "\(a.acc)")
            Color.mLine.frame(width: 1)
            stripItem(label: "net today", value: a.gross > 0 ? fmt(a.net, prefix: "$") : "—")
            Color.mLine.frame(width: 1)
            stripItem(label: "real $/hr", value: fmt(rhr.isFinite ? rhr : nil, prefix: "$"))
        }
        .frame(height: 58)
        .background(Color.mSurface)
        .cornerRadius(10)
    }

    private func stripItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.mText)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.mFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Actions

    private func logOffer(_ decision: String) {
        guard let p = pay, let m = miles else { return }
        var o = Offer()
        o.pay      = p
        o.miles    = m
        o.mins     = mins
        o.dpm      = Calculations.dpm(pay: p, miles: m)
        o.decision = decision
        o.merchant = merchant.trimmingCharacters(in: .whitespaces)
        o.zone     = zone.trimmingCharacters(in: .whitespaces)
        store.addOffer(o)
        clearInputs()
    }

    private func logMissed(_ decision: String) {
        var o = Offer()
        o.decision = decision
        o.missed   = true
        o.merchant = merchant.trimmingCharacters(in: .whitespaces)
        o.zone     = zone.trimmingCharacters(in: .whitespaces)
        store.addOffer(o)
    }

    private func clearInputs() {
        payStr = ""; miStr = ""; minStr = ""
        merchant = ""; zone = ""
    }

    private func shareJSON() {
        guard let data = store.exportJSON() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("meter_backup.json")
        try? data.write(to: url)
        presentShare(url)
    }

    private func presentShare(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        root.present(vc, animated: true)
    }
}
