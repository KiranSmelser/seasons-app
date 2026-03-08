import SwiftUI
import StoreKit

struct SettingsView: View {
    let locationService: LocationService
    @AppStorage("colorSchemePreference") private var colorSchemePref = AppColorScheme.system.rawValue
    @Environment(\.requestReview) private var requestReview

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

            // MARK: About
            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Button("Rate Seasons") { requestReview() }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
