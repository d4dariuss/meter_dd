import Foundation
import SwiftUI

class AppState: ObservableObject {

    @Published var data: AppData          = AppData()
    @Published var activeShift: Date?     = nil
    @Published var activeOdoStart: Double? = nil

    // Up to 3 in-progress accepted offers (not persisted across launches)
    @Published var activeOffers: [Offer]  = []

    // In-memory soft-delete buffer — survives the session, cleared on next launch
    @Published var recentlyDeleted: [Offer] = []

    private static var dataURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meter_data.json")
    }

    init() { load() }

    // MARK: – Persistence

    func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let raw = try? Data(contentsOf: Self.dataURL),
              let decoded = try? dec.decode(AppData.self, from: raw) else { return }
        data = decoded
    }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        try? enc.encode(data).write(to: Self.dataURL)
    }

    // MARK: – Convenience accessors

    var offers:   [Offer]     { data.offers   }
    var shifts:   [Shift]     { data.shifts   }
    var settings: AppSettings { data.settings }

    // MARK: – Offer mutations

    // Accepts an offer and immediately starts the drive timer. Pass gpsMeters from
    // tracker.meters if GPS is active so actualMiles can be computed on delivery.
    func acceptOffer(_ o: Offer, gpsMeters: Double? = nil) {
        guard activeOffers.count < 3 else { return }
        var live = o
        live.driveStart = Date()
        live.gpsAtStart = gpsMeters
        data.offers.append(live)
        activeOffers.append(live)
        save()
    }

    func addOffer(_ o: Offer) {
        data.offers.append(o)
        save()
    }

    func updateOffer(_ o: Offer) {
        guard let i = data.offers.firstIndex(where: { $0.id == o.id }) else { return }
        data.offers[i] = o
        // Propagate zone to all entries for the same merchant in one write
        if !o.merchant.isEmpty && !o.zone.isEmpty {
            for j in data.offers.indices where j != i && data.offers[j].merchant == o.merchant {
                data.offers[j].zone = o.zone
            }
        }
        save()
    }

    func deleteOffer(id: String) {
        if let o = data.offers.first(where: { $0.id == id }) {
            recentlyDeleted.insert(o, at: 0)
            if recentlyDeleted.count > 10 { recentlyDeleted.removeLast() }
        }
        data.offers.removeAll { $0.id == id }
        save()
    }

    func recoverOffer(_ o: Offer) {
        recentlyDeleted.removeAll { $0.id == o.id }
        data.offers.append(o)
        data.offers.sort { $0.ts < $1.ts }
        save()
    }

    func clearRecentlyDeleted() {
        recentlyDeleted.removeAll()
    }

    func undoLast() {
        guard !data.offers.isEmpty else { return }
        let last = data.offers.removeLast()
        activeOffers.removeAll { $0.id == last.id }
        save()
    }

    // MARK: – Active order state machine (all methods take offer id)

    func markAtStore(id: String) {
        guard let i = activeOffers.firstIndex(where: { $0.id == id }) else { return }
        var o = activeOffers[i]
        if let ds = o.driveStart {
            o.driveMin = Date().timeIntervalSince(ds) / 60
        }
        o.waitStart = Date()
        activeOffers[i] = o
        updateOffer(o)
    }

    func markGotFood(id: String) {
        guard let i = activeOffers.firstIndex(where: { $0.id == id }) else { return }
        var o = activeOffers[i]
        if let ws = o.waitStart {
            o.wait = Date().timeIntervalSince(ws) / 60
        }
        o.customerDriveStart = Date()
        activeOffers[i] = o
        updateOffer(o)
    }

    func markDelivered(id: String, gpsMeters: Double? = nil) {
        guard let i = activeOffers.firstIndex(where: { $0.id == id }) else { return }
        var o = activeOffers[i]
        if let cs = o.customerDriveStart {
            o.customerDriveMin = Date().timeIntervalSince(cs) / 60
        }
        o.deliveredAt = Date()
        if let start = o.gpsAtStart, let current = gpsMeters, current > start {
            o.actualMiles = (current - start) / 1609.344
        }
        updateOffer(o)
        activeOffers.remove(at: i)
    }

    func cancelActiveOrder(id: String) {
        activeOffers.removeAll { $0.id == id }
    }

    // MARK: – Merchant notes

    func note(for merchant: String) -> String {
        data.merchantNotes[merchant.lowercased().trimmingCharacters(in: .whitespaces)] ?? ""
    }

    func setNote(for merchant: String, note: String) {
        let key = merchant.lowercased().trimmingCharacters(in: .whitespaces)
        if note.trimmingCharacters(in: .whitespaces).isEmpty {
            data.merchantNotes.removeValue(forKey: key)
        } else {
            data.merchantNotes[key] = note
        }
        save()
    }

    // MARK: – Shift mutations

    func clockIn(odo: Double?) {
        let now = Date()
        activeShift    = now
        activeOdoStart = odo
        let s = Shift(id: UUID().uuidString, start: now, end: nil, odoStart: odo, odoEnd: nil)
        data.shifts.append(s)
        save()
    }

    func clockOut(odo: Double?) {
        let now = Date()
        // Seal any orders still in progress so nothing hangs open after the dash ends
        for i in activeOffers.indices.reversed() {
            var o = activeOffers[i]
            if o.driveMin == nil, let ds = o.driveStart { o.driveMin = now.timeIntervalSince(ds) / 60 }
            if o.wait == nil, let ws = o.waitStart { o.wait = now.timeIntervalSince(ws) / 60 }
            if o.customerDriveMin == nil, let cs = o.customerDriveStart { o.customerDriveMin = now.timeIntervalSince(cs) / 60 }
            o.deliveredAt = now
            if let j = data.offers.firstIndex(where: { $0.id == o.id }) { data.offers[j] = o }
            activeOffers.remove(at: i)
        }
        guard let start = activeShift else { return }
        if let i = data.shifts.lastIndex(where: { $0.start == start }) {
            data.shifts[i].end    = now
            data.shifts[i].odoEnd = odo
        }
        activeShift    = nil
        activeOdoStart = nil
        save()
    }

    func updateShift(_ s: Shift) {
        guard let i = data.shifts.firstIndex(where: { $0.id == s.id }) else { return }
        data.shifts[i] = s
        save()
    }

    // MARK: – Settings

    func updateSettings(_ s: AppSettings) {
        data.settings = s
        save()
    }

    // MARK: – Computed

    var todayOffers: [Offer] {
        let cal = Calendar.current
        return data.offers.filter {
            cal.isDateInToday($0.ts) && $0.decision == "accept" && !$0.missed
        }
    }

    func shiftHours(todayOnly: Bool) -> Double {
        let cal = Calendar.current
        var total = 0.0
        for s in data.shifts {
            if todayOnly && !cal.isDateInToday(s.start) { continue }
            let end = s.end ?? (activeShift.map { _ in Date() } ?? s.start)
            total += end.timeIntervalSince(s.start) / 3600
        }
        return total
    }

    func odoMiles(todayOnly: Bool) -> Double {
        let cal = Calendar.current
        return data.shifts.reduce(0.0) { sum, s in
            if todayOnly && !cal.isDateInToday(s.start) { return sum }
            guard let a = s.odoStart, let b = s.odoEnd, b > a else { return sum }
            return sum + (b - a)
        }
    }

    func realHr(todayOnly: Bool) -> Double {
        let h = shiftHours(todayOnly: todayOnly)
        guard h > 0 else { return .nan }
        let src = todayOnly
            ? todayOffers
            : data.offers.filter { $0.decision == "accept" && !$0.missed }
        let net = src.reduce(0.0) { sum, o in
            let pay   = (o.finalPay ?? o.pay)   ?? 0
            let miles = (o.actualMiles ?? o.miles) ?? 0
            return sum + pay - miles * data.settings.cpm
        }
        return net / h
    }

    var needsBackup: Bool {
        data.offers.count - data.lastExportLen >= 25
    }

    var recentMerchants: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for o in data.offers.reversed() {
            let m = o.merchant.trimmingCharacters(in: .whitespaces)
            guard !m.isEmpty, !seen.contains(m) else { continue }
            seen.insert(m)
            result.append(m)
            if result.count >= 6 { break }
        }
        return result
    }

    var hiddenTipStats: (n: Int, total: Double, avg: Double, pct: Double) {
        let pairs = data.offers.filter {
            $0.decision == "accept" && !$0.missed && $0.pay != nil && $0.finalPay != nil
        }
        guard !pairs.isEmpty else { return (0, 0, 0, 0) }
        let bumped = pairs.filter { ($0.finalPay ?? 0) > ($0.pay ?? 0) }
        let total  = bumped.reduce(0.0) { $0 + (($1.finalPay ?? 0) - ($1.pay ?? 0)) }
        return (
            bumped.count,
            total,
            bumped.isEmpty ? 0 : total / Double(bumped.count),
            Double(bumped.count) / Double(pairs.count) * 100
        )
    }

    // MARK: – Export

    func exportCSV(todayOnly: Bool) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        var rows = ["date,time,decision,missed,restaurant,zone,pay,miles,actual_miles,mins,dpm,drive_min,wait_min,customer_drive_min,final_pay,hidden_bump"]
        let src = todayOnly
            ? data.offers.filter { Calendar.current.isDateInToday($0.ts) }
            : data.offers

        for o in src {
            let bump: String
            if let fp = o.finalPay, let p = o.pay, fp > p {
                bump = String(format: "%.2f", fp - p)
            } else { bump = "" }

            let f2: (Double) -> String = { String(format: "%.2f", $0) }
            let f1: (Double) -> String = { String(format: "%.1f", $0) }
            let f0: (Double) -> String = { String(format: "%.0f", $0) }
            let cols: [String] = [
                dateFmt.string(from: o.ts),
                timeFmt.string(from: o.ts),
                o.decision,
                o.missed ? "1" : "0",
                o.merchant,
                o.zone,
                o.pay.map(f2)                  ?? "",
                o.miles.map(f2)                ?? "",
                o.actualMiles.map(f2)          ?? "",
                o.mins.map(f0)                 ?? "",
                o.dpm.map(f2)                  ?? "",
                o.driveMin.map(f1)             ?? "",
                o.wait.map(f1)                 ?? "",
                o.customerDriveMin.map(f1)     ?? "",
                o.finalPay.map(f2)             ?? "",
                bump
            ]
            rows.append(cols.joined(separator: ","))
        }

        data.lastExportLen = data.offers.count
        save()
        return rows.joined(separator: "\n")
    }

    func exportShiftsCSV() -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        var rows = ["date,clock_in,clock_out,hours,odo_start,odo_end,miles"]
        for s in data.shifts {
            let hrs = s.end.map { $0.timeIntervalSince(s.start) / 3600 }
            let mi: Double
            if let a = s.odoStart, let b = s.odoEnd, b > a { mi = b - a } else { mi = 0 }

            rows.append([
                dateFmt.string(from: s.start),
                timeFmt.string(from: s.start),
                s.end.map { timeFmt.string(from: $0) } ?? "",
                hrs.map { String(format: "%.2f", $0) } ?? "",
                s.odoStart.map { String(format: "%.1f", $0) } ?? "",
                s.odoEnd.map   { String(format: "%.1f", $0) } ?? "",
                String(format: "%.1f", mi)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    func exportJSON() -> Data? {
        data.lastExportLen = data.offers.count
        save()
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        enc.dateEncodingStrategy = .iso8601
        return try? enc.encode(data)
    }

    func importJSON(_ incoming: AppData) {
        // Update existing records and add new ones (incoming wins on conflict)
        var offerIndex = Dictionary(uniqueKeysWithValues: data.offers.enumerated().map { ($1.id, $0) })
        for o in incoming.offers {
            if let i = offerIndex[o.id] {
                data.offers[i] = o   // overwrite with corrected data
            } else {
                data.offers.append(o)
                offerIndex[o.id] = data.offers.count - 1
            }
        }

        var shiftIndex = Dictionary(uniqueKeysWithValues: data.shifts.enumerated().map { ($1.id, $0) })
        for s in incoming.shifts {
            if let i = shiftIndex[s.id] {
                data.shifts[i] = s
            } else {
                data.shifts.append(s)
                shiftIndex[s.id] = data.shifts.count - 1
            }
        }

        // Merge merchant notes (incoming wins on conflict)
        for (key, note) in incoming.merchantNotes {
            data.merchantNotes[key] = note
        }

        data.offers.sort { $0.ts < $1.ts }
        data.shifts.sort { $0.start < $1.start }
        save()
    }

    func resetAll() {
        data           = AppData()
        activeShift    = nil
        activeOdoStart = nil
        activeOffers   = []
        save()
    }
}
