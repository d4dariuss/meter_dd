import SwiftUI

extension Color {
    static let mBg      = Color(hex: 0x0E1217)
    static let mSurface = Color(hex: 0x161C24)
    static let mElev    = Color(hex: 0x1E262F)
    static let mLine    = Color(hex: 0x2A333E)
    static let mText    = Color(hex: 0xE7EDF3)
    static let mMuted   = Color(hex: 0xA6B1BE)
    static let mFaint   = Color(hex: 0x76818F)
    static let mAccent  = Color(hex: 0x4FC3E8)
    static let mGreen   = Color(hex: 0x3FB950)
    static let mAmber   = Color(hex: 0xE3B341)
    static let mOrange  = Color(hex: 0xF0883E)
    static let mRed     = Color(hex: 0xF85149)

    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
