import SwiftUI
import StoreKit
import UserNotifications
import os

struct SettingsView: View {
    let authService: AuthService
    let locationService: LocationService
    @AppStorage("colorSchemePreference") private var colorSchemePref = AppColorScheme.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "SettingsView")

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

            // MARK: Account Deletion
            if authService.isSignedIn {
                Section {
                    Button("Delete Account & Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(isDeleting)
                    .confirmationDialog(
                        "Delete Account",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            Task {
                                isDeleting = true
                                defer { isDeleting = false }
                                do {
                                    try await syncCoordinator.deleteAllUserData()
                                    try await authService.signOut()
                                    dismiss()
                                } catch {
                                    logger.error("Account deletion error: \(error, privacy: .private)")
                                    errorMessage = friendlyMessage(for: error)
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your synced data and sign you out. This cannot be undone.")
                    }
                } footer: {
                    Text("Permanently deletes all synced data and signs you out.")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("cancel") || desc.contains("dismiss") {
            return "Operation was cancelled."
        }
        if desc.contains("network") || desc.contains("internet") ||
           desc.contains("offline") || desc.contains("connection") {
            return "No internet connection. Please check your network and try again."
        }
        return "Something went wrong. Please try again."
    }
}
