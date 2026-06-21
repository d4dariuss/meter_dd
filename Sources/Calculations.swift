import Foundation

enum Calculations {

    static func dpm(pay: Double, miles: Double) -> Double {
        miles > 0 ? pay / miles : .nan
    }

    static func level(dpm: Double, pay: Double, s: AppSettings) -> String {
        guard dpm.isFinite else { return "none" }
        var lv: String
        if      dpm >= s.mileGreen { lv = "green"  }
        else if dpm >= s.mileOk   { lv = "amber"  }
        else if dpm >= s.mileMin  { lv = "orange" }
        else                       { lv = "red"    }
        if pay.isFinite && pay < s.minPayout && (lv == "green" || lv == "amber") {
            lv = "orange"
        }
        return lv
    }

    static func netOffer(pay: Double, miles: Double, cpm: Double) -> Double {
        pay - miles * cpm
    }

    static func netHr(pay: Double, miles: Double, mins: Double, cpm: Double) -> Double {
        guard mins > 0 else { return .nan }
        return netOffer(pay: pay, miles: miles, cpm: cpm) / mins * 60
    }

    // Rolling 100-offer AR estimate seeded by currentAR setting
    static func estAR(offers: [Offer], currentAR: Double) -> (pct: Double, n: Int, valid: Bool) {
        let win = Array(offers.suffix(100))
        let n   = win.count
        let acc = Double(win.filter { $0.decision == "accept" }.count)
        if currentAR > 0 {
            let virt = Double(max(0, 100 - n))
            return (acc + virt * currentAR / 100.0, n, true)
        }
        if n < 10 { return (.nan, n, false) }
        return (acc / Double(n) * 100.0, n, true)
    }

    static func agg(offers: [Offer], cpm: Double) -> AggResult {
        var r = AggResult()
        for o in offers {
            r.seen += 1
            if o.decision == "accept" {
                r.acc += 1
                if !o.missed {
                    let pay   = o.finalPay ?? o.pay   ?? 0
                    let miles = o.actualMiles ?? o.miles ?? 0
                    r.gross += pay
                    r.net   += pay - miles * cpm
                    r.miles += miles
                    r.mins  += o.mins ?? 0
                }
            } else {
                r.dec += 1
            }
        }
        if r.seen > 0 { r.acceptPct = Double(r.acc) / Double(r.seen) * 100 }
        if r.miles > 0 { r.avgDpm = r.gross / r.miles }
        if r.mins  > 0 { r.netHr  = r.net / r.mins * 60 }
        return r
    }

    static func daypart(of date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 11..<14: return "lunch"
        case 17..<21: return "dinner"
        case 21...23, 0..<2: return "late"
        default: return "off"
        }
    }

    static func isFriSat(_ date: Date) -> Bool {
        let wd = Calendar.current.component(.weekday, from: date)
        return wd == 6 || wd == 7
    }

    static func merchantStats(offers: [Offer], filterFn: (Offer) -> Bool) -> [MerchantStat] {
        var groups: [String: [Offer]] = [:]
        for o in offers {
            let m = o.merchant.trimmingCharacters(in: .whitespaces)
            guard !m.isEmpty && filterFn(o) else { continue }
            let z = o.zone.trimmingCharacters(in: .whitespaces)
            let key = z.isEmpty ? m : "\(m)|\(z)"
            groups[key, default: []].append(o)
        }

        return groups.compactMap { key, list -> MerchantStat? in
            let parts = key.split(separator: "|", maxSplits: 1)
            let name  = String(parts[0])
            let zone  = parts.count > 1 ? String(parts[1]) : ""

            let accepted = list.filter { $0.decision == "accept" && !$0.missed }
            let declined = list.filter { $0.decision == "decline" }
            guard !list.isEmpty else { return nil }

            let waits = accepted.compactMap { $0.wait }.sorted()
            let dpmVals: [Double] = accepted.compactMap { o in
                guard let p = o.pay, let m = o.miles, m > 0 else { return nil }
                return p / m
            }

            return MerchantStat(
                key: key,
                name: name,
                zone: zone,
                waitN: waits.count,
                avgWait: waits.isEmpty ? .nan : waits.reduce(0, +) / Double(waits.count),
                medWait: waits.isEmpty ? .nan : waits[waits.count / 2],
                worstWait: waits.last ?? .nan,
                avgDpm: dpmVals.isEmpty ? .nan : dpmVals.reduce(0, +) / Double(dpmVals.count),
                accCount: accepted.count,
                decCount: declined.count
            )
        }
        .sorted {
            let a = $0.medWait.isFinite ? $0.medWait : -1
            let b = $1.medWait.isFinite ? $1.medWait : -1
            return a > b
        }
    }
}
