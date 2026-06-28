# Plan — Live Destination Estimation + Speed-Limit Compare

**Feature:** While driving an active order leg, continuously re-estimate the time
to the destination from the driver's *live* speed, and compare current speed
against the road's posted speed limit.

**Status:** Plan only. Not yet implemented.
**Target:** Meter iOS (SwiftUI, iOS 16+, Swift 5.9, XcodeGen `project.yml`).
**Branch:** `claude/ios-destination-estimation-1x2cm2`.

---

## 1. What this adds (and why it fits Meter)

Meter already tracks the dasher through a per-order state machine
(`AppState.activeOffers`: accept → at store → got food → delivered) and already
has a live GPS pipeline (`LocationTracker` emits `lastSpeedMph`, `lastAccuracy`,
and accumulated `meters` on every fix). What it does **not** do today is tell the
driver, *for the leg they are on right now*, "you'll arrive in ~X min at your
current pace" and "you're 8 mph over the limit here."

This feature is a thin, self-contained layer on top of the existing location
pipeline. It does **not** replace turn-by-turn navigation (the driver still uses
DoorDash/Google/Apple Maps to navigate); it gives Meter its own arrival estimate
and a speed-vs-limit readout that updates live, which feeds two things Meter cares
about:

1. **Better leg-time data.** Today `driveMin` / `customerDriveMin` are measured
   only *after the fact*. A live ETA lets the driver see a running estimate, and
   lets us record a predicted-vs-actual delta for future offer evaluation.
2. **Speed-limit awareness.** A glanceable "over the limit" indicator is a safety
   nudge and a foundation for later analytics (e.g. zones where the driver
   habitually speeds, which correlate with risk and ticket exposure).

### Explicit non-goals (v1)
- No route guidance, no turn-by-turn, no rerouting.
- No automatic ticketing/enforcement logic.
- No reliance on a paid maps SDK being mandatory — speed limit is a *pluggable,
  optional* enhancement that degrades gracefully when unavailable.

---

## 2. The hard part: iOS does not give you the speed limit

Current speed is easy — `CLLocation.speed` (m/s) is already converted to mph in
`LocationTracker`. **Posted speed limit is the real engineering problem**, because
Apple exposes no public API for it. MapKit/`MKDirections` will *render* speed
limits inside Apple's own Maps but does not vend the number to third-party apps.

So speed limit must come from a road-data source keyed by the driver's current
coordinate (and ideally heading, to disambiguate divided roads). Options:

| Source | Speed-limit coverage | Cost | Offline | Notes |
|---|---|---|---|---|
| **OpenStreetMap (Overpass API / local extract)** | `maxspeed` tag, patchy but huge | Free | Yes, if you bundle/cache an extract | No SLA; rate-limited public servers; coverage varies by region. Best free option. |
| **HERE Maps API** | Strong, purpose-built | Paid (free tier exists) | Limited | Industry standard for speed limits. |
| **TomTom API** | Strong | Paid (free tier) | Limited | Good speed-limit product. |
| **Mapbox** | Via map-matching | Paid | Tiles cacheable | Speed limit available through navigation/map-matching APIs. |
| **Apple MapKit** | Not vended to 3rd parties | Free | — | Cannot use for the number. |

### Recommendation
Build against a **`SpeedLimitProvider` protocol** so the data source is swappable,
and ship two concrete implementations:

1. **`OSMOverpassSpeedLimitProvider` (default, free).** Query nearby ways with a
   `maxspeed` tag around the current coordinate, pick the nearest way whose
   bearing roughly matches the driver's heading, parse `maxspeed`
   (`"35 mph"`, `"50"`, `"50 km/h"`, `"signals"`, `"none"`). Aggressively cache by
   tile so we are not hammering the network or the battery.
2. **`NullSpeedLimitProvider` (fallback).** Always returns `nil`. The UI must be
   fully functional with no speed-limit data — the ETA half works regardless.

A paid `HERESpeedLimitProvider` can be added later behind the same protocol
without touching the UI or the estimator. **v1 ships #1 + #2.** This keeps the
feature free, privacy-respecting, and with no hard third-party dependency.

> Decision needed from product owner: confirm "free / OSM-backed, best-effort
> speed limits" is acceptable for v1 vs. paying for a commercial provider. See
> Open Questions.

---

## 3. Architecture

New, isolated module. Nothing here mutates existing files' *logic*; integration is
additive (new published properties, one new card in the active-order UI).

```
Sources/
  Estimation/
    DestinationEstimator.swift     core: remaining distance, smoothed speed, ETA
    SpeedLimitProvider.swift       protocol + NullSpeedLimitProvider
    OSMOverpassSpeedLimitProvider.swift   default free provider + tile cache
    SpeedLimitMonitor.swift        marries live speed to the posted limit (+hysteresis)
    EstimationModels.swift         value types (Destination, ETAEstimate, SpeedLimitReading)
  Views/
    DestinationCardView.swift      the live card shown on the active leg
    SpeedLimitBadge.swift          the speed-vs-limit chip
```

### Data flow

```
CLLocationManager
   │ didUpdateLocations
   ▼
LocationTracker  ──(new)──►  publishes `lastLocation: CLLocation?`  (already has speed/accuracy)
   │
   │  (DestinationEstimator observes the tracker)
   ▼
DestinationEstimator
   ├─ remaining straight-line distance to Destination.coordinate (CL distance)
   ├─ smoothed speed (EMA of recent fixes, parked-state aware)
   ├─ ETA = remaining / effectiveSpeed  → ETAEstimate (published)
   └─ asks SpeedLimitProvider for the current limit (throttled, cached)
         ▼
   SpeedLimitMonitor → SpeedLimitReading { limitMph?, currentMph, deltaMph, state }
         ▼
   DestinationCardView / SpeedLimitBadge  (SwiftUI, observes the estimator)
```

`DestinationEstimator` is an `ObservableObject`, created and owned alongside the
existing `LocationTracker` in `MeterApp` and injected via `@EnvironmentObject`,
mirroring how `LocationTracker` and `AppState` are already wired.

---

## 4. Models

```swift
// EstimationModels.swift
import CoreLocation

/// Where the current leg is headed. For v1 the destination coordinate is supplied
/// by the driver (drop a pin / paste address that we geocode), since Meter does
/// not receive the DoorDash destination programmatically.
struct Destination: Equatable {
    var coordinate: CLLocationCoordinate2D
    var label: String          // "Pickup — Chipotle" / "Dropoff"
    enum Leg { case toStore, toCustomer }
    var leg: Leg
}

/// A single live arrival estimate.
struct ETAEstimate: Equatable {
    var remainingMeters: Double
    var effectiveSpeedMps: Double     // smoothed, floored
    var secondsRemaining: Double      // remainingMeters / effectiveSpeedMps
    var etaClock: Date                // now + secondsRemaining
    var confidence: Confidence        // gps quality + speed stability
    enum Confidence { case high, medium, low }
}

/// Posted-limit comparison for the driver's current position.
struct SpeedLimitReading: Equatable {
    var limitMph: Double?             // nil when unknown / no data
    var currentMph: Double
    var deltaMph: Double?             // current - limit, nil if limit unknown
    enum State { case unknown, under, atLimit, over, wayOver }
    var state: State
}
```

`CLLocationCoordinate2D` is not `Equatable` by default — add a small internal
`==` or wrap lat/lon, so `Destination` diffs cleanly for SwiftUI.

### Persistence touch (Models.swift)
Add **optional** fields to `Offer` so they decode old data unchanged (the file
already uses `decodeIfPresent` defaults — follow that exact pattern):

```swift
// Offer — new optional fields
var predToStoreMin: Double?      // ETA snapshot captured when leg started
var predToCustomerMin: Double?   // "
var maxOverLimitMph: Double?     // worst over-limit delta seen on this order
```

These let us later compare predicted vs actual leg time and surface speeding
exposure per order/zone, with zero migration work.

---

## 5. Core algorithms

### 5.1 Remaining distance
v1 uses **great-circle straight-line distance** from the current fix to
`Destination.coordinate` (`CLLocation.distance(from:)`). It is cheap, offline, and
needs no routing API. It *underestimates* real road distance, so we apply a
**winding factor** `k` (default ~1.3, tunable) to convert crow-flies → road
distance: `roadMeters ≈ straightMeters * k`.

> v2 option: replace the straight-line estimate with `MKDirections.calculate`
> (Apple, free) for an actual road distance + Apple's own ETA, refreshed only when
> the driver deviates significantly. Behind the same `ETAEstimate` output, so the
> UI doesn't change. Listed in milestones, not v1.

### 5.2 Smoothed effective speed
Raw `CLLocation.speed` is noisy and goes to 0 at lights. Naively dividing distance
by instantaneous speed makes ETA jump to infinity at every red light. So:

- Maintain an **exponential moving average** of speed over recent *moving* fixes:
  `ema = α·v + (1−α)·ema`, `α` ≈ 0.3 (tunable).
- **Parked / stopped handling:** if instantaneous speed < ~2 mph for < N seconds,
  hold the last EMA (you're at a light, not done). If stopped longer, decay toward
  a floor.
- **Speed floor:** never divide by less than a floor (e.g. 8 mph effective) so ETA
  stays finite and sane; surface low confidence instead of a wild number.
- Reject fixes with `horizontalAccuracy` worse than the existing 25 m gate (reuse
  `LocationTracker`'s filtering philosophy) and negative `speed` sentinels.

### 5.3 ETA
```
secondsRemaining = (straightMeters * k) / max(effectiveSpeedMps, floorMps)
etaClock         = now + secondsRemaining
```
Smooth the *displayed* `secondsRemaining` too (second, lighter EMA) so the on-screen
number doesn't twitch every fix. Confidence = function of GPS accuracy + how stable
the recent speed EMA has been + whether destination is set precisely.

### 5.4 Speed-limit comparison (with hysteresis)
Comparing `currentMph` to `limitMph` naively flickers between under/over at the
boundary. Use a tolerance band + hysteresis:

```
let tol = 2.0           // mph grace
state =
  limit == nil                         → .unknown
  current <= limit + tol               → .under   (or .atLimit within ±tol)
  current <= limit + 10                → .over
  else                                 → .wayOver
```
Require the state to persist for ~2 s before changing the badge, so a momentary GPS
speed spike doesn't flash red. Track `maxOverLimitMph` for the active order.

### 5.5 OSM `maxspeed` parsing
The `maxspeed` tag is messy. Handle: bare number = km/h by OSM convention
(`"50"` → 50 km/h → 31 mph), explicit `"35 mph"`, `"50 km/h"`, implicit values
(`"signals"`, `"none"`, `"walk"`, country-coded `"DE:urban"`). Unparseable → `nil`
(treated as unknown, never as a fake limit). Unit-test this parser hard (§9).

---

## 6. UI

A single new card, `DestinationCardView`, shown in `DecideView` **only while an
order leg is active and a destination is set**. It sits with the existing active-
order controls. Visual language reuses `Theme.swift` tokens (`mSurface`, `mAccent`,
`mGreen`/`mAmber`/`mOrange`/`mRed`, `mText`/`mMuted`).

```
┌──────────────────────────────────────────────┐
│  Dropoff · 2.4 mi                             │
│                                                │
│        ETA  7 min        arrive 6:42 PM        │   ← big, live
│                                                │
│   ┌─────────────┐   current 41 · limit 35     │
│   │   41 / 35   │   ●  6 over                  │   ← SpeedLimitBadge
│   └─────────────┘   (red when over, amber edge,│
│      mph             green/gray when under/unk)│
│                                                │
│   confidence: ● medium   GPS ±12 m             │
└──────────────────────────────────────────────┘
```

- **ETA** large and glanceable; **arrival clock** beside it.
- **`SpeedLimitBadge`**: a chip rendering `current / limit`. Color by
  `SpeedLimitReading.state` — gray (unknown), green (under), amber (at/just over),
  red (way over). When `limitMph == nil`, show just current speed and a subtle
  "limit unavailable here" — *never* an empty/fake limit.
- **Confidence + GPS accuracy** shown small, honest (matches the README's existing
  "GPS is an estimate" tone).
- Setting a destination: a compact control on the active order to **drop a pin on a
  mini map** or **enter/geocode an address**; on the leg-start transitions
  (`acceptOffer`, `markGotFood`) we can prompt for it. No DoorDash integration is
  possible, so destination is driver-supplied in v1.

Accessibility: badge state must not rely on color alone — include the
"6 over" / "under limit" text and a VoiceOver label.

---

## 7. Integration points (surgical, additive)

1. **`LocationTracker.swift`** — publish the raw last fix so the estimator can read
   coordinate + heading, not just the scalar outputs:
   ```swift
   @Published var lastLocation: CLLocation?   // set in didUpdateLocations
   ```
   No change to existing distance/speed logic.

2. **`MeterApp.swift`** — instantiate `DestinationEstimator(tracker:)` and inject it
   as an `@EnvironmentObject`, exactly as `LocationTracker`/`AppState` are today.

3. **`DecideView.swift`** — when `store.activeOffers` has a current leg and a
   destination is set, render `DestinationCardView()`. Wire leg transitions
   (`acceptOffer` → toStore, `markGotFood` → toCustomer) to set/clear the estimator's
   `Destination`.

4. **`AppState.swift` / `Models.swift`** — on `markAtStore` / `markDelivered`, snapshot
   the live `ETAEstimate` into the new optional `Offer` fields, and persist
   `maxOverLimitMph`. Pure additions; existing methods keep working.

5. **`project.yml` / `Info.plist`** — no new background mode (reuses existing
   `location`). Add `NSAppTransportSecurity` only if the chosen Overpass endpoint
   needs it (prefer an HTTPS endpoint and add nothing). If using `MKDirections`
   later, no extra key. Add a short usage note for any network calls.

---

## 8. Privacy, cost, battery

- **Privacy:** coordinates leave the device *only* if a network speed-limit
  provider is used. The Overpass query sends a bounding box around the driver.
  Mitigate by (a) snapping queries to a coarse tile grid, (b) caching so we query
  rarely, (c) making the speed-limit feature **opt-in** in Settings with clear copy,
  and (d) keeping the ETA half fully on-device (no network at all). `NullSpeedLimit`
  + on-device ETA = zero data exfiltration.
- **Cost:** OSM/Overpass is free; respect rate limits (cache, throttle, back off).
  No paid dependency in v1.
- **Battery:** the GPS stream already runs during a dash, so the estimator adds
  almost no location cost. Network speed-limit lookups are throttled (e.g. at most
  once per ~30 s or per ~250 m moved) and served from cache otherwise.

---

## 9. Testing

- **Unit tests (pure, no device):**
  - `maxspeed` parser: the full zoo of tag values → expected mph or nil.
  - Speed EMA + floor: a sequence of noisy/zero speeds → stable, finite effective
    speed; verify red-light hold behavior.
  - ETA math: known distance + known speed → known seconds; winding factor applied.
  - Hysteresis state machine: boundary oscillation does not flip the badge faster
    than the debounce window.
  - `Destination` / `Offer` Codable round-trips, incl. decoding **old** JSON with
    the new fields absent (regression-guard the `decodeIfPresent` defaults).
- **Simulated drives:** Xcode location simulation + bundled **GPX** routes
  (a city route with lights, a highway route) to eyeball ETA stability and badge
  behavior without real driving.
- **Field test checklist:** known commute with a known posted limit; confirm the
  badge trips correctly and ETA converges as you approach.

---

## 10. Milestones

- **M0 — Scaffolding (no UI).** `Estimation/` module, models, `SpeedLimitProvider`
  protocol + `NullSpeedLimitProvider`, `DestinationEstimator` with straight-line
  distance + speed EMA + ETA. Unit tests for the math. *On-device, no network.*
- **M1 — UI + integration.** `DestinationCardView`, destination-setting (pin/geocode),
  wire into `DecideView` + leg transitions, publish `lastLocation`. ETA visible and
  live. Speed shown; limit still "unavailable."
- **M2 — Speed limit (OSM).** `OSMOverpassSpeedLimitProvider` + tile cache +
  `maxspeed` parser + `SpeedLimitMonitor` + hysteresis. Badge goes live. Opt-in in
  Settings.
- **M3 — Persistence + analytics.** Snapshot predicted vs actual leg time and
  `maxOverLimitMph` into `Offer`; surface a small predicted-vs-actual and "speeding
  exposure by zone" readout in Stats.
- **M4 (optional) — Road-distance ETA.** Swap straight-line for `MKDirections` road
  distance/ETA behind the same `ETAEstimate`; add `HERESpeedLimitProvider` for users
  who want premium limit coverage.

---

## 11. Risks / edge cases

- **Speed-limit data gaps.** OSM coverage is uneven; rural/new roads may have no
  `maxspeed`. UI must show "unavailable," never guess. This is the biggest known
  limitation and is called out in copy.
- **Wrong road matched.** Divided highways / frontage roads near each other: use
  heading to disambiguate; when ambiguous, prefer "unknown" over a wrong limit.
- **GPS speed noise / tunnels / urban canyon.** Reuse the existing accuracy gate;
  hold last good estimate and drop confidence rather than showing garbage.
- **Straight-line underestimate.** Winding factor is a heuristic; M4 fixes it with
  real routing. Label ETA as an estimate (matches app tone).
- **Destination is driver-supplied.** Meter can't read the DoorDash address. If the
  driver doesn't set one, the card simply shows the live speed/limit half and no ETA.
- **Background.** ETA card is a foreground glance; don't promise background ETA
  notifications in v1.
- **Legal/safety framing.** Present speed-limit info as informational only; no
  claims of accuracy/enforcement. Encourage eyes on the road (glanceable, large).

---

## 12. Open questions (need product owner input)

1. **Speed-limit source for v1:** free/OSM best-effort (recommended) vs. pay for a
   commercial provider (HERE/TomTom) for fuller coverage?
2. **Destination entry UX:** drop-a-pin, address geocode, or both? Prompt on every
   leg or make it optional?
3. **Scope of "estimation":** is the ETA the deliverable, or also the predicted-vs-
   actual analytics (M3)?
4. **Speeding data:** do you want the app to *record* over-limit exposure per order/
   zone (M3), or only show it live and never store it (privacy)?
5. **Audible/haptic alert** when going over the limit, or visual-only?
```
