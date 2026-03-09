import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    let locationService: LocationService
    @AppStorage("colorSchemePreference") private var colorSchemePref = AppColorScheme.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @Environment(\.requestReview) private var requestReview
    @Environment(NotificationService.self) private var notificationService

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            // MARK: Region
            Section("Region") {
                Picker("Growing Region", selection: Binding(
                    get: { locationService.region },
                    set: { locationService.setManualRegion($0) }
                )) {
                    ForEach(GrowingRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                .pickerStyle(.navigationLink)

                if locationService.authorizationStatus == .denied ||
                   locationService.authorizationStatus == .restricted {
                    Button("Open Location Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else {
                    Button {
                        locationService.useCurrentLocation()
                    } label: {
                        Label("Use My Location", systemImage: "location.circle")
                    }
                }
            }

            // MARK: Appearance
            Section("Appearance") {
                Picker("Color Scheme", selection: $colorSchemePref) {
                    Text("System").tag(AppColorScheme.system.rawValue)
                    Text("Light").tag(AppColorScheme.light.rawValue)
                    Text("Dark").tag(AppColorScheme.dark.rawValue)
                }
                .pickerStyle(.segmented)
            }

            // MARK: Notifications
            Section("Notifications") {
                Toggle("Monthly Season Updates", isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let granted = await notificationService.requestPermission()
                                if granted {
                                    notificationsEnabled = true
                                    await notificationService.scheduleMonthlyNotifications(for: locationService.region)
                                } else {
                                    notificationsEnabled = false
                                }
                            }
                        } else {
                            notificationsEnabled = false
                            notificationService.cancelAllNotifications()
                        }
                    }
                ))

                if notificationsEnabled {
                    Text("You'll get a notification on the 1st of each month with what's just come into season in your region.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if notificationsEnabled && !notificationService.isAuthorized {
                    Button("Open Notification Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                #if DEBUG
                if notificationsEnabled {
                    Button("Send Test Notification") {
                        Task {
                            let items = ProduceDataService.shared.inSeason(
                                region: locationService.region,
                                month: Calendar.current.component(.month, from: Date())
                            )
                            let content = UNMutableNotificationContent()
                            content.title = "What's In Season This Month"
                            content.body = notificationService.notificationBody(items: items, region: locationService.region)
                            content.sound = .default
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                            let request = UNNotificationRequest(identifier: "debug-test", content: content, trigger: trigger)
                            try? await UNUserNotificationCenter.current().add(request)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                #endif
            }

            // MARK: About
            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("Privacy Policy", destination: URL(string: "https://kiransmelser.com/seasons-privacy")!)
                Button("Rate Seasons") { requestReview() }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
