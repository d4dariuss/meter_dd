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
