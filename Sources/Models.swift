import Foundation

struct Offer: Codable, Identifiable {
    var id: String       = UUID().uuidString
    var ts: Date         = Date()
    var pay: Double?
    var miles: Double?
    var mins: Double?
    var dpm: Double?
    var decision: String = "accept"
    var merchant: String = ""
    var zone: String     = ""
    var missed: Bool     = false
    var finalPay: Double?
    var wait: Double?
    var driveStart: Date?
    var driveMin: Double?
    var waitStart: Date?
    // Customer delivery leg (set when pickup is complete)
    var customerDriveStart: Date?
    var customerDriveMin: Double?
    var deliveredAt: Date?
    // GPS-measured distance and snapshot for per-order tracking
    var actualMiles: Double?
    var gpsAtStart: Double?
}

struct Shift: Codable, Identifiable {
    var id: String    = UUID().uuidString
    var start: Date
    var end: Date?
    var odoStart: Double?
    var odoEnd: Double?
}

struct AppSettings: Codable {
    var cpm: Double       = 0.30
    var mileGreen: Double = 2.0
    var mileOk: Double    = 1.5
    var mileMin: Double   = 1.0
    var hrTarget: Double  = 25.0
    var arFloor: Double   = 70.0
    var irsRate: Double   = 0.725
    var minPayout: Double = 6.0
    var slowWait: Double  = 10.0
    var currentAR: Double = 91.0
    var mpg: Double       = 25.0
    var gasPrice: Double  = 3.50

    // Custom decoder so that JSON missing mpg/gasPrice (exported before those fields existed)
    // still decodes successfully — Swift's synthesized init(from:) doesn't fall back to
    // default values, it throws keyNotFound for any non-Optional missing key.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cpm       = try c.decodeIfPresent(Double.self, forKey: .cpm)       ?? 0.30
        mileGreen = try c.decodeIfPresent(Double.self, forKey: .mileGreen) ?? 2.0
        mileOk    = try c.decodeIfPresent(Double.self, forKey: .mileOk)    ?? 1.5
        mileMin   = try c.decodeIfPresent(Double.self, forKey: .mileMin)   ?? 1.0
        hrTarget  = try c.decodeIfPresent(Double.self, forKey: .hrTarget)  ?? 25.0
        arFloor   = try c.decodeIfPresent(Double.self, forKey: .arFloor)   ?? 70.0
        irsRate   = try c.decodeIfPresent(Double.self, forKey: .irsRate)   ?? 0.725
        minPayout = try c.decodeIfPresent(Double.self, forKey: .minPayout) ?? 6.0
        slowWait  = try c.decodeIfPresent(Double.self, forKey: .slowWait)  ?? 10.0
        currentAR = try c.decodeIfPresent(Double.self, forKey: .currentAR) ?? 91.0
        mpg       = try c.decodeIfPresent(Double.self, forKey: .mpg)       ?? 25.0
        gasPrice  = try c.decodeIfPresent(Double.self, forKey: .gasPrice)  ?? 3.50
    }
}

struct AppData: Codable {
    var offers: [Offer]                  = []
    var shifts: [Shift]                  = []
    var lastExportLen: Int               = 0
    var settings: AppSettings            = AppSettings()
    var merchantNotes: [String: String]  = [:]   // lowercased merchant name → note
}

struct AggResult {
    var seen: Int      = 0
    var acc: Int       = 0
    var dec: Int       = 0
    var gross: Double  = 0
    var net: Double    = 0
    var miles: Double  = 0
    var mins: Double   = 0
    var acceptPct: Double = .nan
    var avgDpm: Double    = .nan
    var netHr: Double     = .nan
}

struct MerchantStat: Identifiable {
    var id: String { key }
    var key: String
    var name: String
    var zone: String
    var waitN: Int
    var avgWait: Double
    var medWait: Double
    var worstWait: Double
    var avgDpm: Double
    var accCount: Int
    var decCount: Int
}
