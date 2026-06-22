import SwiftUI

struct DecideView: View {
    @EnvironmentObject var store:   AppState
    @EnvironmentObject var tracker: LocationTracker

    @State private var payStr:   String = ""
    @State private var miStr:    String = ""
    @State private var minStr:   String = ""
    @State private var merchant: String = ""
    @State private var zone:     String = ""
    @State private var odoStr:   String = ""
    @State private var now:      Date   = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: – Derived values

    private var pay:   Double? { Double(payStr) }
    private var miles: Double? { Double(miStr)  }
    private var mins:  Double? { Double(minStr) }

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
    private var canAccept: Bool { canDecide && store.activeOffers.count < 3 }

    // Merchant history for pre-accept intel
    private var merchantHistory: MerchantStat? {
        let key = merchant.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return nil }
        return Calculations.merchantStats(offers: store.data.offers) {
            $0.merchant.lowercased() == key
        }.first
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

                // Active orders (up to 3 stacked)
                ForEach(store.activeOffers) { active in
                    ActiveOrderCard(offer: active)
                }
                if store.activeOffers.count >= 3 { maxOrdersBanner }

                // Gauge + inputs always visible; Accept disabled at max 3
                gaugeCard
                    .tutorialAnchor("gauge")
                inputCard
                actionButtons
                    .tutorialAnchor("accept-decline")
                undoMissedRow
                    .tutorialAnchor("missed-row")

                // Shift clock (always visible)
                shiftClockCard
                    .tutorialAnchor("shift-clock")

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
        let ar      = Calculations.estAR(offers: store.offers, currentAR: store.settings.currentAR)
        let arColor = ar.valid && ar.pct >= store.settings.arFloor ? Color.mGreen : Color.mRed
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
                            RoundedRectangle(cornerRadius: 2).fill(Color.mLine).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2).fill(arColor)
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
        .tutorialAnchor("ar-header")
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
            .background(Color.mAmber.opacity(0.1))
            .cornerRadius(8)
            .colorBorder(.mAmber, radius: 8, opacity: 0.4)
        }
    }

    // MARK: – Gauge card (pre-accept)

    private var gaugeCard: some View {
        Card {
            VStack(spacing: 14) {
                // $/mi + verdict
                Text(dpm.isFinite ? String(format: "$%.2f/mi", dpm) : "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(levelColor(lv))

                Text(verdict)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(levelColor(lv))

                // Metric chips
                HStack(spacing: 10) {
                    if let n = nph {
                        gaugeChip("NET/HR", String(format: "$%.0f", n),
                                  n >= store.settings.hrTarget ? .mGreen : .mRed)
                    }
                    if let net = netOff {
                        gaugeChip("NET/OFFER", String(format: "$%.2f", net),
                                  net >= 0 ? .mText : .mRed)
                    }
                    if let hist = merchantHistory, hist.waitN > 0, hist.medWait.isFinite {
                        gaugeChip("WAIT", String(format: "~%.0fm", hist.medWait),
                                  hist.medWait >= store.settings.slowWait ? .mOrange : .mGreen)
                    }
                }

                // Merchant history (shown when restaurant field is filled)
                if let hist = merchantHistory {
                    merchantIntelRow(hist)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    private func gaugeChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(.mFaint)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.mElev).cornerRadius(8)
        .cardBorder(8)
    }

    // Pre-accept merchant intel strip
    private func merchantIntelRow(_ hist: MerchantStat) -> some View {
        let confidence: String = {
            switch hist.waitN {
            case 10...: return "reliable"
            case 6...:  return "useful"
            case 3...:  return "early"
            default:    return "weak data"
            }
        }()
        let note = store.note(for: hist.name)

        return VStack(alignment: .leading, spacing: 6) {
            Color.mLine.frame(height: 1)
                .padding(.horizontal, -20)

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.mFaint)
                Text("\(hist.accCount) visit\(hist.accCount == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundColor(.mFaint)
                if hist.waitN > 0 {
                    Text("·")
                        .foregroundColor(.mLine)
                    Text(String(format: "avg wait %.0fm", hist.avgWait))
                        .font(.system(size: 12))
                        .foregroundColor(hist.avgWait >= store.settings.slowWait ? .mOrange : .mMuted)
                    Text("·")
                        .foregroundColor(.mLine)
                    Text(confidence)
                        .font(.system(size: 11))
                        .foregroundColor(.mFaint)
                } else {
                    Text("· no wait data yet")
                        .font(.system(size: 12)).foregroundColor(.mFaint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(.mAmber)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.mMuted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 0)
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
        VStack(spacing: 8) {
            Card {
                VStack(spacing: 0) {
                    HStack {
                        Text("Restaurant")
                            .font(.system(size: 14)).foregroundColor(.mMuted)
                            .frame(width: 90, alignment: .leading)
                        TextField("name", text: $merchant)
                            .font(.system(size: 15)).foregroundColor(.mText).submitLabel(.done)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)

                    MLine()

                    HStack {
                        Text("Zone")
                            .font(.system(size: 14)).foregroundColor(.mMuted)
                            .frame(width: 90, alignment: .leading)
                        TextField("area / market", text: $zone)
                            .font(.system(size: 15)).foregroundColor(.mText).submitLabel(.done)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                }
                .tutorialAnchor("restaurant-zone")

                if !store.recentMerchants.isEmpty {
                    MLine()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.recentMerchants, id: \.self) { m in
                                Button(m) {
                                    merchant = m
                                    if let prev = store.offers.last(where: { $0.merchant == m }) {
                                        zone = prev.zone
                                    }
                                }
                                .font(.system(size: 12)).foregroundColor(.mAccent)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.mElev).cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                }
            }

            HStack(spacing: 8) {
                inputCell("Pay $", $payStr)
                inputCell("Miles", $miStr)
                inputCell("Mins",  $minStr)
            }
            .tutorialAnchor("input-grid")
        }
    }

    private func inputCell(_ label: String, _ text: Binding<String>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.mFaint)
            NumericField(text: text, placeholder: "0", alignment: .center, fontSize: 22, fontWeight: .semibold)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.mSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mLine, lineWidth: 0.5))
    }

    // MARK: – Action buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { logDecline() } label: {
                Text("Decline")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(canDecide ? .mRed : .mFaint)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.mSurface).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(canDecide ? Color.mRed.opacity(0.5) : Color.mLine, lineWidth: 1))
            }
            .disabled(!canDecide)

            Button { logAccept() } label: {
                Text("Accept")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(canAccept ? .white : .mFaint)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(canAccept ? levelColor(lv) : Color.mElev)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(canAccept ? levelColor(lv) : Color.mLine, lineWidth: 1))
            }
            .disabled(!canAccept)
        }
    }

    // MARK: – Undo + Missed

    private var undoMissedRow: some View {
        HStack(spacing: 10) {
            Button {
                store.undoLast()
            } label: {
                Label("Undo last", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 13)).foregroundColor(.mMuted)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Color.mSurface).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mLine, lineWidth: 0.5))
            }
            Spacer()
            Text("Missed?").font(.system(size: 13)).foregroundColor(.mFaint)
            Button("+ dec") { logMissed("decline") }
                .font(.system(size: 13)).foregroundColor(.mRed)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Color.mSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mLine, lineWidth: 0.5))
            Button("+ acc") { logMissed("accept") }
                .font(.system(size: 13)).foregroundColor(.mGreen)
                .padding(.vertical, 8).padding(.horizontal, 10)
                .background(Color.mSurface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mLine, lineWidth: 0.5))
        }
    }

    // MARK: – Max orders banner

    private var maxOrdersBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.mAmber)
            Text("3 active orders — complete one to accept more")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.mAmber)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mAmber.opacity(0.1))
        .cornerRadius(8)
        .colorBorder(.mAmber, radius: 8, opacity: 0.4)
    }

    // MARK: – Shift clock

    private var shiftClockCard: some View {
        Card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SHIFT CLOCK")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.mFaint)
                    if let start = store.activeShift {
                        Text(fmtDuration(now.timeIntervalSince(start)))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.mText)
                        Text("since \(start, style: .time)")
                            .font(.system(size: 12)).foregroundColor(.mMuted)
                    } else {
                        Text("Not clocked in")
                            .font(.system(size: 15)).foregroundColor(.mMuted)
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
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background((store.activeShift == nil ? Color.mAccent : Color.mOrange).opacity(0.12))
                    .cornerRadius(8)
                    .colorBorder(store.activeShift == nil ? .mAccent : .mOrange, radius: 8, opacity: 0.5)

                    HStack(spacing: 6) {
                        Text("Odo:").font(.system(size: 12)).foregroundColor(.mFaint)
                        NumericField(text: $odoStr, placeholder: "mi", alignment: .left, fontSize: 13)
                            .frame(width: 70, height: 26)
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
            stripItem("orders",    "\(a.acc)")
            Color.mLine.frame(width: 1)
            stripItem("net today", a.gross > 0 ? fmt(a.net, prefix: "$") : "—")
            Color.mLine.frame(width: 1)
            stripItem("real $/hr", fmt(rhr.isFinite ? rhr : nil, prefix: "$"))
        }
        .frame(height: 58)
        .background(Color.mSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mLine, lineWidth: 0.5))
    }

    private func stripItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.mText)
            Text(label).font(.system(size: 11)).foregroundColor(.mFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Actions

    private func logAccept() {
        guard let p = pay, let m = miles, store.activeOffers.count < 3 else { return }
        var o = Offer()
        o.pay = p; o.miles = m; o.mins = mins
        o.dpm = Calculations.dpm(pay: p, miles: m)
        o.decision = "accept"
        o.merchant = merchant.trimmingCharacters(in: .whitespaces)
        o.zone     = zone.trimmingCharacters(in: .whitespaces)
        let gps = tracker.isTracking ? tracker.meters : nil
        store.acceptOffer(o, gpsMeters: gps)
        clearInputs()
    }

    private func logDecline() {
        guard let p = pay, let m = miles else { return }
        var o = Offer()
        o.pay = p; o.miles = m; o.mins = mins
        o.dpm = Calculations.dpm(pay: p, miles: m)
        o.decision = "decline"
        o.merchant = merchant.trimmingCharacters(in: .whitespaces)
        o.zone     = zone.trimmingCharacters(in: .whitespaces)
        store.addOffer(o)
        clearInputs()
    }

    private func logMissed(_ decision: String) {
        var o = Offer()
        o.decision = decision; o.missed = true
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meter_backup.json")
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        root.present(vc, animated: true)
    }
}

// MARK: – Active order card

struct ActiveOrderCard: View {
    @EnvironmentObject var store:   AppState
    @EnvironmentObject var tracker: LocationTracker
    var offer: Offer

    @State private var noteText: String = ""
    @State private var noteSaved: Bool  = false

    // Phase: 0=driving to restaurant  1=waiting at store  2=driving to customer
    private var phase: Int {
        if offer.customerDriveStart != nil { return 2 }
        if offer.waitStart != nil { return 1 }
        return 0
    }

    private var dpm: Double {
        guard let p = offer.pay, let m = offer.miles, m > 0 else { return .nan }
        return p / m
    }
    private var lv: String {
        guard let p = offer.pay, offer.miles != nil else { return "none" }
        return Calculations.level(dpm: dpm, pay: p, s: store.settings)
    }

    var body: some View {
        Card {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACTIVE ORDER")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.mAccent)
                        HStack(spacing: 8) {
                            if !offer.merchant.isEmpty {
                                Text(offer.merchant)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.mText)
                            }
                            if !offer.zone.isEmpty {
                                Text(offer.zone)
                                    .font(.system(size: 13))
                                    .foregroundColor(.mFaint)
                            }
                        }
                        HStack(spacing: 8) {
                            if let p = offer.pay {
                                Text(String(format: "$%.2f", p))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.mText)
                            }
                            if let m = offer.miles {
                                Text(String(format: "%.1f mi", m))
                                    .font(.system(size: 13))
                                    .foregroundColor(.mMuted)
                            }
                            if dpm.isFinite {
                                Text(String(format: "$%.2f/mi", dpm))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(levelColor(lv))
                            }
                        }
                    }
                    Spacer()
                    Button {
                        store.cancelActiveOrder(id: offer.id)
                    } label: {
                        Text("Skip timers")
                            .font(.system(size: 12))
                            .foregroundColor(.mFaint)
                    }
                }
                .padding(16)

                MLine()

                // Drive phase
                if phase == 0 {
                    phaseRow(
                        icon: "car.fill",
                        color: .mAccent,
                        label: "Driving to pickup",
                        since: offer.driveStart,
                        buttonLabel: "At Store →",
                        buttonColor: .mAmber
                    ) {
                        store.markAtStore(id: offer.id)
                    }
                }

                // Wait phase
                if phase == 1 {
                    if let dm = offer.driveMin {
                        doneChip(icon: "car.fill", text: String(format: "Drive %.1f min", dm))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        MLine()
                    }
                    phaseRow(
                        icon: "figure.stand",
                        color: .mOrange,
                        label: "Waiting for food",
                        since: offer.waitStart,
                        buttonLabel: "Got Food →",
                        buttonColor: .mGreen
                    ) {
                        store.markGotFood(id: offer.id)
                    }
                }

                // Customer drive phase
                if phase == 2 {
                    HStack(spacing: 8) {
                        if let dm = offer.driveMin {
                            doneChip(icon: "car.fill", text: String(format: "Drive %.1f min", dm))
                        }
                        if let w = offer.wait {
                            doneChip(icon: "timer", text: String(format: "Wait %.0f min", w))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MLine()
                    phaseRow(
                        icon: "figure.walk",
                        color: .mAccent,
                        label: "Driving to customer",
                        since: offer.customerDriveStart,
                        buttonLabel: "Dropped Off ✓",
                        buttonColor: .mGreen
                    ) {
                        let gps = tracker.isTracking ? tracker.meters : nil
                        store.markDelivered(id: offer.id, gpsMeters: gps)
                    }
                }

                MLine()

                // Notes for this merchant
                notesSection
            }
        }
    }

    private func doneChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.mGreen)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.mGreen)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.mGreen)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.mGreen.opacity(0.1))
        .cornerRadius(6)
        .colorBorder(.mGreen, radius: 6, opacity: 0.35)
    }

    private func phaseRow(icon: String, color: Color, label: String,
                          since: Date?, buttonLabel: String,
                          buttonColor: Color, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                }
                if let since = since {
                    LiveTimer(since: since,
                              font: .system(size: 32, weight: .bold, design: .monospaced))
                }
            }
            Spacer()
            Button(action: action) {
                Text(buttonLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(buttonColor)
                    .cornerRadius(8)
            }
        }
        .padding(16)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundColor(.mAmber)
                Text(offer.merchant.isEmpty ? "Store notes" : "Notes for \(offer.merchant)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mMuted)
                Spacer()
                if noteSaved {
                    Text("Saved")
                        .font(.system(size: 11))
                        .foregroundColor(.mGreen)
                }
            }

            TextField("parking, entrance, tip history, anything useful...", text: $noteText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.mText)
                .lineLimit(2...4)
                .onSubmit { saveNote() }
                .onChange(of: noteText) { _ in saveNote() }
        }
        .padding(16)
        .onAppear {
            noteText = offer.merchant.isEmpty ? "" : store.note(for: offer.merchant)
        }
    }

    private func saveNote() {
        guard !offer.merchant.isEmpty else { return }
        store.setNote(for: offer.merchant, note: noteText)
        noteSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { noteSaved = false }
    }
}
