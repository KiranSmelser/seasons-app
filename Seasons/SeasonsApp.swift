import SwiftUI
import SwiftData

@main
struct SeasonsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [CarbonLog.self, Favorite.self])
    }
}
