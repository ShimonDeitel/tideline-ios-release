import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("quickmath.haptics") private var hapticsEnabled = true
    @AppStorage("quickmath.reminderOn") private var reminderOn = false
    @AppStorage("quickmath.reminderHour") private var reminderHour = 9
    @AppStorage("quickmath.reminderMinute") private var reminderMinute = 0

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "QuickMath \(v)"
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = c.hour ?? 9
                reminderMinute = c.minute ?? 0
                if reminderOn { Reminders.schedule(hour: reminderHour, minute: reminderMinute) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                appearanceSection
                drillSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.qmAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Erase Progress?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases your drills on this device. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("QuickMath Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock QuickMath Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("One-time purchase. All difficulty tiers, history charts, weak-spot focus and sharing.")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var drillSection: some View {
        Section("Drill") {
            Toggle("Haptics", isOn: $hapticsEnabled)
            Toggle("Daily reminder", isOn: $reminderOn)
                .onChange(of: reminderOn) { _, on in
                    if on {
                        Task {
                            let granted = await Reminders.requestAuthorization()
                            if granted {
                                Reminders.schedule(hour: reminderHour, minute: reminderMinute)
                            } else {
                                reminderOn = false
                            }
                        }
                    } else {
                        Reminders.cancel()
                    }
                }
            if reminderOn {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button("Erase Progress", role: .destructive) { showDeleteConfirm = true }
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/quickmath-site/privacy.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
