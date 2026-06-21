import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    @EnvironmentObject var store: AppState
    @State private var scope:           String = "today"
    @State private var showReset:       Bool   = false
    @State private var showImport:      Bool   = false
    @State private var importError:     String = ""
    @State private var showImportError: Bool   = false

    private var isToday: Bool { scope == "today" }

    private var srcOffers: [Offer] {
        isToday
            ? store.offers.filter { Calendar.current.isDateInToday($0.ts) }
            : store.offers
    }

    private var a: AggResult {
        Calculations.agg(offers: srcOffers.filter { !$0.missed }, cpm: store.settings.cpm)
    }

    private var shiftH:  Double { store.shiftHours(todayOnly: isToday) }
    private var odoMi:   Double { store.odoMiles(todayOnly: isToday)   }
    private var rhr:     Double { store.realHr(todayOnly: isToday)     }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // Scope toggle
                    Picker("", selection: $scope) {
                        Text("Today").tag("today")
                        Text("All time").tag("all")
                    }
                    .pickerStyle(.segmented)
                    .padding(16)

                    // Stats table
                    Card {
                        statRows
                    }
                    .padding(.horizontal, 16)

                    // Hidden tip section
                    SectionHeader(title: "Hidden tip check")
                    Card {
                        hiddenTipRows
                    }
                    .padding(.horizontal, 16)

                    // Your data section
                    SectionHeader(title: "Your data")
                    Card {
                        dataButtons
                    }
                    .padding(.horizontal, 16)

                    Text("Meter v1.1 · native iOS · your data stays on this device")
                        .font(.system(size: 12))
                        .foregroundColor(.mFaint)
                        .padding(28)
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Reset all data?", isPresented: $showReset) {
                Button("Reset", role: .destructive) { store.resetAll() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes all offers, shifts, and settings. Export a backup first.")
            }
            .alert("Import failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError)
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [UTType.json]
            ) { result in
                handleImport(result)
            }
        }
    }

    // MARK: – Stat rows

    @ViewBuilder
    private var statRows: some View {
        let seen = a.seen + srcOffers.filter(\.missed).count
        StatRow(label: "Offers seen",       value: "\(seen)")
        MLine()
        StatRow(label: "Accepted",          value: "\(a.acc)")
        MLine()
        StatRow(label: "Declined",          value: "\(a.dec)")
        MLine()
        StatRow(label: "Accept rate",
                value: a.acceptPct.isFinite ? String(format: "%.1f%%", a.acceptPct) : "—")
        MLine()
        StatRow(label: "Gross pay",         value: fmt(a.gross,  prefix: "$"))
        MLine()
        StatRow(label: "Net after miles",   value: fmt(a.net,    prefix: "$"),
                highlight: a.net > 0 ? .mGreen : (a.net < 0 ? .mRed : nil))
        MLine()
        StatRow(label: "Order miles",       value: fmt(a.miles,  suffix: " mi", decimals: 1))
        MLine()
        StatRow(label: "Real miles (odo)",  value: odoMi > 0 ? String(format: "%.1f mi", odoMi) : "—")
        MLine()
        StatRow(label: "Active order hrs",
                value: a.mins > 0 ? String(format: "%.1f hr", a.mins / 60) : "—")
        MLine()
        StatRow(label: "Avg $/mile",        value: fmt(a.avgDpm, prefix: "$"))
        MLine()
        StatRow(label: "Active-order $/hr", value: fmt(a.netHr,  prefix: "$"))
        MLine()
        StatRow(label: "Shift hrs",
                value: shiftH > 0 ? String(format: "%.1f hr", shiftH) : "—")
        MLine()
        StatRow(label: "Real $/hr (shift)", value: fmt(rhr.isFinite ? rhr : nil, prefix: "$"),
                highlight: rhr.isFinite ? (rhr >= store.settings.hrTarget ? .mGreen : .mOrange) : nil)

        if !isToday {
            MLine()
            StatRow(label: "Tax write-off",
                    value: odoMi > 0 ? fmt(odoMi * store.settings.irsRate, prefix: "$") : "—")
            MLine()
            StatRow(label: "Write-off basis",
                    value: odoMi > 0 ? String(format: "%.1f mi @ $%.3f/mi", odoMi, store.settings.irsRate) : "—")
        }
    }

    // MARK: – Hidden tip rows

    @ViewBuilder
    private var hiddenTipRows: some View {
        let tips = store.hiddenTipStats
        if tips.n == 0 {
            Text("Enter final pay in Log to see tip analysis")
                .font(.system(size: 13))
                .foregroundColor(.mFaint)
                .padding(16)
        } else {
            StatRow(label: "Orders with final pay", value: "\(tips.n)")
            MLine()
            StatRow(label: "Had hidden tip",
                    value: String(format: "%.0f%%", tips.pct))
            MLine()
            StatRow(label: "Total hidden tips", value: fmt(tips.total, prefix: "$"),
                    highlight: .mGreen)
            MLine()
            StatRow(label: "Avg hidden tip",    value: fmt(tips.avg, prefix: "$"))
        }
    }

    // MARK: – Data buttons

    @ViewBuilder
    private var dataButtons: some View {
        exportRow("Export CSV (all)",    icon: "doc.text")    { shareCSV(todayOnly: false) }
        MLine()
        exportRow("Export CSV (today)",  icon: "doc.text")    { shareCSV(todayOnly: true)  }
        MLine()
        exportRow("Export JSON",         icon: "arrow.up.doc")    { shareJSON()            }
        MLine()
        exportRow("Export Shifts CSV",   icon: "calendar")    { shareShiftsCSV()           }
        MLine()
        exportRow("Import JSON",         icon: "arrow.down.doc")  { showImport = true      }
        MLine()
        Button {
            showReset = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Reset all data")
                Spacer()
            }
            .foregroundColor(.mRed)
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }

    private func exportRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundColor(.mAccent)
                Text(title).foregroundColor(.mText)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.mFaint)
            }
            .font(.system(size: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }

    // MARK: – Export helpers

    private func shareCSV(todayOnly: Bool) {
        let csv = store.exportCSV(todayOnly: todayOnly)
        let name = todayOnly ? "meter_today.csv" : "meter_offers.csv"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        present(url)
    }

    private func shareShiftsCSV() {
        let csv = store.exportShiftsCSV()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meter_shifts.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        present(url)
    }

    private func shareJSON() {
        guard let data = store.exportJSON() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meter_data.json")
        try? data.write(to: url)
        present(url)
    }

    private func present(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        root.present(vc, animated: true)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "Meter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let raw = try Data(contentsOf: url)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let incoming = try dec.decode(AppData.self, from: raw)
            store.importJSON(incoming)
        } catch {
            importError     = error.localizedDescription
            showImportError = true
        }
    }
}
