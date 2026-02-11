import SwiftUI
import SwiftData

@main
struct SeasonsApp: App {
    @State private var authService = AuthService()
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let syncService: SyncService

    init() {
        let schema = Schema([CarbonLog.self, Favorite.self, PendingSyncDeletion.self])
        let config = ModelConfiguration(schema: schema)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed since last install — delete the old store and retry
            let storeURL = config.url
            let related = [
                storeURL,
                storeURL.deletingPathExtension().appendingPathExtension("store-shm"),
                storeURL.deletingPathExtension().appendingPathExtension("store-wal")
            ]
            for url in related { try? FileManager.default.removeItem(at: url) }
            container = try! ModelContainer(for: schema, configurations: [config])
        }
        self.modelContainer = container

        let auth = AuthService()
        self._authService = State(initialValue: auth)
        self.syncService = SyncService(
            supabase: auth.supabase,
            modelContainer: container
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let user = authService.currentUser {
                Task {
                    await syncService.performSync(userId: user.id)
                }
            }
        }
        .onChange(of: authService.isSignedIn) { wasSignedIn, isNowSignedIn in
            if !wasSignedIn && isNowSignedIn, let user = authService.currentUser {
                Task {
                    await syncService.uploadAllLocalData(userId: user.id)
                }
            }
        }
    }
}
