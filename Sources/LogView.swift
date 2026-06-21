import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: AppState
    @State private var editingOffer: Offer? = nil

    var body: some View {
        NavigationView {
            Group {
                if store.offers.isEmpty && store.recentlyDeleted.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if !store.recentlyDeleted.isEmpty {
                            recentlyDeletedBanner
                        }
                        if store.offers.isEmpty {
                            emptyState
                        } else {
                            List {
                                ForEach(store.offers.reversed()) { offer in
                                    OfferRow(offer: offer, onEdit: { editingOffer = $0 })
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                store.deleteOffer(id: offer.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .background(Color.mBg)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tutorialAnchor("log-header")
        }
        .withKeyboardDoneButton()
        .sheet(item: $editingOffer) { offer in
            OfferEditSheet(offer: offer) { updated in
                store.updateOffer(updated)
            }
        }
    }

    // MARK: – Recently deleted banner

    private var recentlyDeletedBanner: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "trash.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.mMuted)
                Text("Recently Deleted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.mMuted)
                Spacer()
                Button("Clear all") { store.clearRecentlyDeleted() }
                    .font(.system(size: 12))
                    .foregroundColor(.mFaint)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)

            ForEach(store.recentlyDeleted) { offer in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.merchant.isEmpty
                             ? (offer.missed ? "Missed offer" : "Offer")
                             : offer.merchant)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.mText)
                        HStack(spacing: 6) {
                            if let p = offer.pay {
                                Text(String(format: "$%.2f", p))
                                    .font(.system(size: 12)).foregroundColor(.mMuted)
                            }
                            Text(offer.ts, style: .time)
                                .font(.system(size: 12)).foregroundColor(.mFaint)
                        }
                    }
                    Spacer()
                    Button("Recover") { store.recoverOffer(offer) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.mAccent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.mAccent.opacity(0.1)).cornerRadius(6)
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
            }

            Divider()
                .background(Color.mLine)
                .padding(.top, 6)
        }
        .background(Color.mSurface)
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
    var onEdit: (Offer) -> Void

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

            // Edit button
            Button {
                onEdit(offer)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
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
            if let am = offer.actualMiles {
                Text(String(format: "GPS %.1f mi", am))
                    .font(.system(size: 12)).foregroundColor(.mGreen)
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
        .tutorialAnchor("log-final-pay")
    }

    private func saveFinalPay() {
        var updated = offer
        updated.finalPay = Double(finalPayStr)
        store.updateOffer(updated)
    }

    // MARK: – Pickup timer

    // 0=nothing  1=driving to restaurant  2=waiting at store
    // 3=driving to customer  4=done
    private var timerState: Int {
        if offer.deliveredAt != nil || offer.customerDriveMin != nil { return 4 }
        if offer.customerDriveStart != nil { return 3 }
        if offer.wait != nil { return 4 }                              // legacy records
        if offer.driveMin != nil && offer.waitStart == nil { return 4 } // legacy
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
                    LiveTimer(since: ds, prefix: "🚗 ", color: .mAccent)
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
                    LiveTimer(since: ws, prefix: "⏱ ", color: .mOrange)
                }
                Button("Got food") {
                    var u = offer
                    if let ws = u.waitStart {
                        u.wait = Date().timeIntervalSince(ws) / 60
                    }
                    u.customerDriveStart = Date()
                    store.updateOffer(u)
                }
                .font(.system(size: 12))
                .foregroundColor(.mGreen)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.mGreen.opacity(0.1)).cornerRadius(7)

            case 3:
                if let dm = offer.driveMin {
                    Text(String(format: "🚗 %.1fm", dm))
                        .font(.system(size: 12)).foregroundColor(.mMuted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.mElev).cornerRadius(6)
                }
                if let w = offer.wait {
                    let wc: Color = w >= store.settings.slowWait ? .mOrange : .mGreen
                    Text(String(format: "⏱ %.0fm", w))
                        .font(.system(size: 12)).foregroundColor(wc)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(wc.opacity(0.1)).cornerRadius(6)
                }
                if let cs = offer.customerDriveStart {
                    LiveTimer(since: cs, prefix: "🚶 ", color: .mAccent)
                }
                Button("Delivered ✓") {
                    var u = offer
                    if let cs = u.customerDriveStart {
                        u.customerDriveMin = Date().timeIntervalSince(cs) / 60
                    }
                    u.deliveredAt = Date()
                    store.updateOffer(u)
                }
                .font(.system(size: 12))
                .foregroundColor(.mGreen)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.mGreen.opacity(0.1)).cornerRadius(7)

            default: // 4 = done
                if let dm = offer.driveMin {
                    Text(String(format: "🚗 %.1fm", dm))
                        .font(.system(size: 12)).foregroundColor(.mMuted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.mElev).cornerRadius(6)
                }
                if let w = offer.wait {
                    let color: Color = w >= store.settings.slowWait ? .mOrange : .mGreen
                    Text(String(format: "⏱ %.0fm", w))
                        .font(.system(size: 12)).foregroundColor(color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.1)).cornerRadius(6)
                }
                if let cdm = offer.customerDriveMin {
                    Text(String(format: "🚶 %.1fm", cdm))
                        .font(.system(size: 12)).foregroundColor(.mMuted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.mElev).cornerRadius(6)
                }
            }
        }
    }
}

// MARK: – Offer edit sheet

struct OfferEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var offer: Offer
    let onSave: (Offer) -> Void

    @State private var payStr:       String = ""
    @State private var miStr:        String = ""
    @State private var minStr:       String = ""
    @State private var fpStr:        String = ""
    @State private var driveStr:     String = ""
    @State private var waitStr:      String = ""
    @State private var custDrStr:    String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SectionHeader(title: "Offer details")
                    Card {
                        editTextRow("Restaurant", text: $offer.merchant)
                        MLine()
                        editTextRow("Zone", text: $offer.zone)
                        MLine()
                        editNumRow("Offer pay $",    str: $payStr)
                        MLine()
                        editNumRow("Miles",          str: $miStr)
                        MLine()
                        editNumRow("Est. mins",      str: $minStr)
                        MLine()
                        editNumRow("Final pay $",    str: $fpStr)
                    }
                    .padding(.horizontal, 16)

                    SectionHeader(title: "Delivery times (minutes)")
                    Card {
                        editNumRow("Drive to restaurant", str: $driveStr)
                        MLine()
                        editNumRow("Wait at restaurant",  str: $waitStr)
                        MLine()
                        editNumRow("Drive to customer",   str: $custDrStr)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 32)
                }
            }
            .scrollDismissesKeyboard(.never)
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Edit Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.mMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .foregroundColor(.mAccent)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateFields() }
        }
        .withKeyboardDoneButton()
    }

    private func populateFields() {
        payStr    = offer.pay.map        { String(format: "%.2f", $0) } ?? ""
        miStr     = offer.miles.map      { String(format: "%.2f", $0) } ?? ""
        minStr    = offer.mins.map       { String(format: "%.0f", $0) } ?? ""
        fpStr     = offer.finalPay.map   { String(format: "%.2f", $0) } ?? ""
        driveStr  = offer.driveMin.map   { String(format: "%.1f", $0) } ?? ""
        waitStr   = offer.wait.map       { String(format: "%.1f", $0) } ?? ""
        custDrStr = offer.customerDriveMin.map { String(format: "%.1f", $0) } ?? ""
    }

    private func saveAndDismiss() {
        offer.pay              = Double(payStr)
        offer.miles            = Double(miStr)
        offer.mins             = Double(minStr)
        offer.finalPay         = Double(fpStr)
        offer.driveMin         = Double(driveStr)
        offer.wait             = Double(waitStr)
        offer.customerDriveMin = Double(custDrStr)
        if let p = offer.pay, let m = offer.miles, m > 0 {
            offer.dpm = p / m
        }
        onSave(offer)
        dismiss()
    }

    private func editTextRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14)).foregroundColor(.mMuted)
                .frame(width: 130, alignment: .leading)
            TextField("", text: text)
                .font(.system(size: 15)).foregroundColor(.mText)
                .submitLabel(.next)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func editNumRow(_ label: String, str: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14)).foregroundColor(.mMuted)
                .frame(width: 130, alignment: .leading)
            TextField("—", text: str)
                .keyboardType(.decimalPad)
                .font(.system(size: 15)).foregroundColor(.mText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
