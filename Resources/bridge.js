/*
 * bridge.js  —  Meter iOS native bridge
 *
 * Injected at document end by WebView.swift, so meter.html stays unchanged.
 *
 *  - Swift calls   window.MeterNative.onUpdate(miles, accuracyMeters, speedMph, tracking)
 *  - Web  calls    window.MeterBridge.start() / .stop() / .requestAlways()
 *
 * It also draws a small floating "GPS x.xx mi" pill with a Track/Stop button so
 * you can confirm tracking works the moment the app launches, before doing any
 * deeper integration with the odometer fields.
 *
 * OPTIONAL deeper hook: if you later add a function named window.onNativeMiles
 * inside meter.html, this bridge will call it with {miles, acc, speed, tracking}
 * on every update, so you can auto-fill the shift odometer if you want.
 */
(function () {
  function post(action) {
    try { window.webkit.messageHandlers.meter.postMessage({ action: action }); }
    catch (e) { /* not running inside the native shell */ }
  }

  var state = { miles: 0, acc: -1, speed: 0, tracking: false };

  window.MeterBridge = {
    isNative: true,
    start: function () { post("startTracking"); },
    stop: function () { post("stopTracking"); },
    requestAlways: function () { post("requestAlways"); },
    get: function () { return state; }
  };

  window.MeterNative = {
    onUpdate: function (miles, acc, speed, tracking) {
      state.miles = miles; state.acc = acc; state.speed = speed; state.tracking = !!tracking;
      render();
      if (typeof window.onNativeMiles === "function") window.onNativeMiles(state);
    }
  };

  var pill = document.createElement("div");
  pill.id = "nativeGps";
  pill.style.cssText =
    "position:fixed;left:50%;transform:translateX(-50%);" +
    "bottom:calc(86px + env(safe-area-inset-bottom));z-index:40;" +
    "background:rgba(30,38,47,.95);border:1px solid #2A333E;color:#E7EDF3;" +
    "font:600 13px -apple-system,system-ui,sans-serif;padding:6px 10px;" +
    "border-radius:999px;display:flex;gap:8px;align-items:center;" +
    "white-space:nowrap;box-shadow:0 6px 20px rgba(0,0,0,.4);";

  var label = document.createElement("span");
  var btn = document.createElement("button");
  btn.type = "button";
  btn.style.cssText =
    "border:none;border-radius:8px;padding:6px 12px;cursor:pointer;" +
    "font:700 12px -apple-system,system-ui,sans-serif;";

  pill.appendChild(label);
  pill.appendChild(btn);

  function render() {
    var acc = state.acc >= 0 ? " ±" + Math.round(state.acc) + "m" : "";
    label.textContent = "GPS " + state.miles.toFixed(2) + " mi" + (state.tracking ? acc : "");
    label.style.color = state.tracking ? "#3FB950" : "#A6B1BE";
    btn.textContent = state.tracking ? "Stop" : "Track";
    btn.style.background = state.tracking ? "rgba(248,81,73,.18)" : "rgba(63,185,80,.18)";
    btn.style.color = state.tracking ? "#F85149" : "#3FB950";
  }

  btn.onclick = function () {
    if (state.tracking) { window.MeterBridge.stop(); }
    else { window.MeterBridge.start(); }
  };

  function mount() { document.body.appendChild(pill); render(); }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount);
  } else {
    mount();
  }
})();
