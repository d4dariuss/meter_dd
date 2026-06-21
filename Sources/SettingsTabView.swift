import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject var store:    AppState
    @EnvironmentObject var tutorial: TutorialManager
    @State private var s:    AppSettings = AppSettings()
    @State private var saved: Bool       = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    SectionHeader(title: "Decision thresholds")
                    Card {
                        settingRow("Strong ≥ $/mi",  $s.mileGreen)
                        MLine()
                        settingRow("OK ≥ $/mi",      $s.mileOk)
                        MLine()
                        settingRow("Floor $/mi",     $s.mileMin)
                        MLine()
                        settingRow("Min payout $",   $s.minPayout)
                        MLine()
                        settingRow("Target net $/hr", $s.hrTarget, decimals: 0)
                    }
                    .padding(.horizontal, 16)
                    .tutorialAnchor("settings-thresholds")

                    SectionHeader(title: "Your numbers")
                    Card {
                        settingRow("Current DoorDash AR %",  $s.currentAR, decimals: 1)
                        MLine()
                        settingRow("Cost per mile $",         $s.cpm,       decimals: 3)
                        MLine()
                        settingRow("Platinum AR floor %",     $s.arFloor,   decimals: 0)
                        MLine()
                        settingRow("IRS deduction $/mi",      $s.irsRate,   decimals: 3)
                        MLine()
                        settingRow("Slow wait flag (min)",    $s.slowWait,  decimals: 0)
                    }
                    .padding(.horizontal, 16)
                    .tutorialAnchor("settings-ar")

                    // Save confirmation
                    if saved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.mGreen)
                            Text("Settings saved")
                                .font(.system(size: 14))
                                .foregroundColor(.mGreen)
                        }
                        .padding(.top, 16)
                    }

                    // Replay tutorial
                    Button {
                        tutorial.start()
                    } label: {
                        Label("Replay Tutorial", systemImage: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.mAccent)
                    }
                    .padding(.top, 24)

                    Text("Meter v1.1 · native iOS · your data stays on this device")
                        .font(.system(size: 12))
                        .foregroundColor(.mFaint)
                        .padding(.top, 8)

                    Spacer(minLength: 32)
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateSettings(s)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .foregroundColor(.mAccent)
                }
            }
        }
        .onAppear { s = store.settings }
    }

    private func settingRow(_ label: String, _ val: Binding<Double>, decimals: Int = 2) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.mMuted)
            Spacer()
            TextField("", value: val, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.mText)
                .frame(width: 90)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
