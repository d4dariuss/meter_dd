import SwiftUI

struct SpotsView: View {
    @EnvironmentObject var store: AppState
    @State private var filter: String = "all"

    private var filterFn: (Offer) -> Bool {
        switch filter {
        case "lunch":  return { Calculations.daypart(of: $0.ts) == "lunch"  }
        case "dinner": return { Calculations.daypart(of: $0.ts) == "dinner" }
        case "late":   return { Calculations.daypart(of: $0.ts) == "late"   }
        case "frisat": return { Calculations.isFriSat($0.ts) }
        default:       return { _ in true }
        }
    }

    private var stats: [MerchantStat] {
        Calculations.merchantStats(offers: store.offers, filterFn: filterFn)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterRow
                Divider().background(Color.mLine)

                if stats.isEmpty {
                    emptyState
                } else {
                    List(stats) { stat in
                        SpotRow(stat: stat)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .background(Color.mBg)
                    .scrollContentBackground(.hidden)
                    .tutorialAnchor("spots-list")
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Spots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["all", "lunch", "dinner", "late", "frisat"], id: \.self) { f in
                    Chip(title: f == "frisat" ? "Fri/Sat" : f.capitalized,
                         active: filter == f) { filter = f }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.mSurface)
        .tutorialAnchor("spots-filter")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 44))
                .foregroundColor(.mFaint)
            Text("No restaurant data yet")
                .font(.system(size: 16))
                .foregroundColor(.mMuted)
            Text("Use the pickup timer in Log to build wait-time rankings")
                .font(.system(size: 13))
                .foregroundColor(.mFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Spot row

struct SpotRow: View {
    @EnvironmentObject var store: AppState
    let stat: MerchantStat

    @State private var noteText: String = ""
    @State private var editingNote: Bool = false

    private var pill: (label: String, color: Color) {
        let med = stat.medWait
        guard med.isFinite else { return ("—", .mFaint) }
        if med < 5                         { return ("fast", .mGreen)  }
        if med < store.settings.slowWait   { return ("ok",   .mAmber)  }
        return ("slow", .mRed)
    }

    private var confidence: String {
        switch stat.waitN {
        case 10...: return "reliable"
        case 6...:  return "useful"
        case 3...:  return "early"
        default:    return "weak"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(stat.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.mText)
                        Badge(text: pill.label, color: pill.color)
                        if !stat.zone.isEmpty {
                            Text(stat.zone)
                                .font(.system(size: 12))
                                .foregroundColor(.mFaint)
                        }
                    }
                    Text(waitLine)
                        .font(.system(size: 12))
                        .foregroundColor(.mMuted)
                }
                Spacer()

                // Wait bar
                if stat.medWait.isFinite {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(pill.color)
                        .frame(width: max(6, min(70, stat.medWait * 3)), height: 12)
                        .padding(.top, 4)
                }
            }

            // Meta line
            HStack(spacing: 12) {
                Text("\(stat.accCount) acc")
                    .font(.system(size: 12)).foregroundColor(.mFaint)
                if stat.decCount > 0 {
                    Text("\(stat.decCount) dec")
                        .font(.system(size: 12)).foregroundColor(.mFaint)
                }
                if stat.avgDpm.isFinite {
                    Text(String(format: "$%.2f/mi", stat.avgDpm))
                        .font(.system(size: 12)).foregroundColor(.mFaint)
                }
                if stat.waitN > 0 {
                    Text("\(stat.waitN) timed · \(confidence)")
                        .font(.system(size: 12)).foregroundColor(.mFaint)
                }
            }

            // Notes row
            noteRow
        }
        .padding(12)
        .background(Color.mSurface)
        .cornerRadius(10)
        .onAppear { noteText = store.note(for: stat.name) }
    }

    @ViewBuilder
    private var noteRow: some View {
        if editingNote {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundColor(.mAmber)
                    .padding(.top, 2)
                TextField("parking, entrance, tip history...", text: $noteText, axis: .vertical)
                    .font(.system(size: 13))
                    .foregroundColor(.mText)
                    .lineLimit(2...4)
                Button("Done") {
                    store.setNote(for: stat.name, note: noteText)
                    editingNote = false
                }
                .font(.system(size: 12))
                .foregroundColor(.mAccent)
            }
            .padding(.top, 4)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundColor(noteText.isEmpty ? .mLine : .mAmber)
                if noteText.isEmpty {
                    Text("Add note")
                        .font(.system(size: 12))
                        .foregroundColor(.mFaint)
                } else {
                    Text(noteText)
                        .font(.system(size: 12))
                        .foregroundColor(.mMuted)
                        .lineLimit(2)
                }
                Spacer()
                Button(noteText.isEmpty ? "Add" : "Edit") {
                    editingNote = true
                }
                .font(.system(size: 12))
                .foregroundColor(.mAccent)
            }
            .padding(.top, 4)
        }
    }

    private var waitLine: String {
        let med   = stat.medWait.isFinite   ? String(format: "%.0f", stat.medWait)   : "—"
        let avg   = stat.avgWait.isFinite   ? String(format: "%.0f", stat.avgWait)   : "—"
        let worst = stat.worstWait.isFinite ? String(format: "%.0f", stat.worstWait) : "—"
        return "med \(med)m · avg \(avg)m · worst \(worst)m"
    }
}
