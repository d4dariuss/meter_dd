# Meter iOS — native shell scaffold

This wraps your existing **`meter.html`** in a native iOS app and adds a
**Core Location mileage tracker** bridged to the web app. The whole app you
already built runs unchanged inside it; the native layer only adds the one thing
a web page cannot do: track GPS miles in the background while your screen is off
or you are in the DoorDash navigation app.

> **Read this first, honest version.** This was written without a Mac or Xcode in
> the loop, so it has **not been compiled or run**. It is a correct-as-written
> starting scaffold, not a finished binary. Expect to fix a small thing or two in
> Xcode (a signing setting, a capability toggle). The code is deliberately small
> so there is little to go wrong.
>
> **Also honest:** GPS path distance is an *estimate*, not a tax-grade number by
> itself. Keep using the **odometer log** inside the app as your audit-proof
> record. Treat GPS as a convenience cross-check.

---

## What you need

- A **Mac with Xcode 15 or newer** (free from the Mac App Store).
- Your **iPhone 14** and its USB cable.
- A **free Apple ID** is enough to install on your own phone (the app works for
  7 days per install, then you reconnect and rebuild). A paid Apple Developer
  account ($99/yr) removes that 7-day limit but is not required to start.

---

## Files in this folder

```
meter-ios/
  Sources/
    MeterApp.swift          app entry point
    ContentView.swift       owns the tracker, shows the web view
    WebView.swift           WKWebView + the JS <-> Swift bridge
    LocationTracker.swift   Core Location distance tracking + GPS filtering
  Resources/
    meter.html              your web app (already copied in)
    bridge.js               injected bridge + the floating "GPS x.xx mi" pill
  Info.plist                permission strings + background mode (XcodeGen path)
  project.yml               OPTIONAL XcodeGen config
  README.md                 this file
```

---

## Build it — the reliable GUI way (recommended)

You are not hand-editing a project file; you create a fresh project in Xcode and
drop these files in. That avoids the fragile parts.

**1. New project**
- Xcode > File > New > Project > **iOS > App** > Next.
- Product Name: **Meter**. Interface: **SwiftUI**. Language: **Swift**.
- Pick a folder and create it.

**2. Add the Swift files**
- Delete the auto-generated `ContentView.swift` (move to Trash).
- Drag the four files from `Sources/` into the project navigator.
- In the dialog, check **Copy items if needed** and that the **Meter** target is
  ticked. (Xcode made its own `MeterApp.swift`; replace it with the one here when
  it asks, or delete its version first.)

**3. Add the web app + bridge**
- Drag `Resources/meter.html` and `Resources/bridge.js` into the project.
- Check **Copy items if needed** and **Add to target: Meter**.
- Click `meter.html`, open the File Inspector (right panel), and confirm
  **Target Membership > Meter** is checked. Do the same for `bridge.js`.
  (This is what puts them in the app bundle so `Bundle.main.url(...)` finds them.)

**4. Location permission text**
- Select the project > **Meter** target > **Info** tab.
- Add two keys (click the +):
  - `Privacy - Location When In Use Usage Description`
    → "Meter measures the miles you drive during a dash so you have a mileage record."
  - `Privacy - Location Always and When In Use Usage Description`
    → "Allow Always so Meter can keep counting miles while you navigate in another app or your screen is off."

**5. Background location (only if you want screen-off tracking)**
- Target > **Signing & Capabilities** > **+ Capability** > **Background Modes**.
- Check **Location updates**.
- If you skip this step, the app still tracks miles while it is the app on screen;
  it just stops when you switch away. (The code only turns on background updates
  after you grant **Always**, so skipping this will not crash it.)

**6. Signing**
- Target > **Signing & Capabilities** > check **Automatically manage signing**.
- Team: pick your **Personal Team** (your Apple ID). Change the Bundle Identifier
  to something unique if Xcode complains, e.g. `com.darius.meter`.

**7. Run on your phone**
- Plug in the iPhone, select it in the device dropdown at the top, press **Run** (▶).
- First run: on the phone, Settings > General > VPN & Device Management > trust
  your developer certificate, then launch again.
- Tap the **Track** pill at the bottom, allow location, and drive. The pill shows
  live miles. To keep counting with the screen off, choose **Always** when iOS
  asks (or in Settings > Meter > Location).

### Optional: the XcodeGen one-liner
If you already use XcodeGen: `cd meter-ios && xcodegen generate && open Meter.xcodeproj`,
then set your Team and run. This uses the included `Info.plist` and `project.yml`.

---

## How the bridge works

- **Web to native:** the injected `bridge.js` exposes `window.MeterBridge.start()`,
  `.stop()`, and `.requestAlways()`, which post messages to Swift.
- **Native to web:** `LocationTracker` calls
  `window.MeterNative.onUpdate(miles, accuracy, speedMph, tracking)` on every fix.
- The floating GPS pill is drawn by `bridge.js`, so you see it working right away
  without touching `meter.html`.

### Optional deeper integration (later)
If you want GPS to auto-fill the shift odometer, add a function named
`window.onNativeMiles` inside `meter.html`. The bridge calls it with
`{miles, acc, speed, tracking}` on every update. Example idea: when a shift is
active, write the rounded miles into the active shift's distance. Tell Claude and
it can wire that cleanly.

---

## Updating the app later

To ship a new version of the web app, replace `Resources/meter.html` with the new
file and rebuild. **Your saved data stays**, because the file origin does not
change between builds. (This is also why the native shell is more durable than
Safari: no more "lost data when the file is replaced" problem.)

---

## Tuning the GPS filter

In `LocationTracker.swift`:
- `desiredAccuracy` — `kCLLocationAccuracyNearestTenMeters` balances accuracy and
  battery. `kCLLocationAccuracyBest` is more precise but drains more.
- The `horizontalAccuracy < 25` and `d >= 5 && d < 2000` checks reject junk points
  and jumps. Loosen or tighten if your mileage reads high (drift) or low (skipping).

---

## App Store note

You do **not** need the App Store for personal use; installing on your own phone
through Xcode is fine. If you ever submit it, background location requires a clear
user benefit and a short explanation in review, which a dasher mileage tracker has.

---

## Planned features

- **Live destination estimation + speed-limit compare** — a live ETA for the
  active order leg that adjusts to your current speed, plus a speed-vs-posted-limit
  readout. Full implementation plan:
  [`docs/PLAN-destination-estimation.md`](docs/PLAN-destination-estimation.md).
