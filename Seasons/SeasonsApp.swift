import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct SeasonsApp: App {
    @State private var authService = AuthService()
    @State private var syncBannerMessage: SyncBannerMessage?
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let syncService: SyncService
    @State private var syncCoordinator: SyncCoordinator

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
        let syncService = SyncService(
            client: SupabaseSyncClient(supabase: auth.supabase),
            modelContainer: container
        )
        self.syncService = syncService
        self._syncCoordinator = State(initialValue: SyncCoordinator(syncService: syncService, authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService, syncBannerMessage: $syncBannerMessage)
                .environment(syncCoordinator)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let user = authService.currentUser {
                Task {
                    let result = await syncService.performSync(userId: user.id)
                    showBanner(for: result)
                }
            }
        }
        .onChange(of: authService.isSignedIn) { wasSignedIn, isNowSignedIn in
            if !wasSignedIn && isNowSignedIn, let user = authService.currentUser {
                Task {
                    let hasInitialSync = await syncService.hasCompletedInitialSync(userId: user.id)
                    let result: SyncResult
                    if hasInitialSync {
                        result = await syncService.performSync(userId: user.id)
                    } else {
                        result = await syncService.uploadAllLocalData(userId: user.id)
                        await syncService.setInitialSyncCompleted(userId: user.id)
                    }
                    showBanner(for: result)
                }
            }
            if wasSignedIn && !isNowSignedIn {
                syncCoordinator.cancelPendingSync()
                Task { @MainActor in
                    await syncService.resetSyncState()
                    let context = modelContainer.mainContext
                    do {
                        try context.delete(model: Favorite.self)
                        try context.delete(model: CarbonLog.self)
                        try context.delete(model: PendingSyncDeletion.self)
                        try context.save()
                    } catch {
                        print("[SeasonsApp] Sign-out cleanup failed: \(error)")
                    }
                }
            }
        }
    }

    private func showBanner(for result: SyncResult) {
        Task { @MainActor in
            withAnimation {
                switch result {
                case .success:
                    syncBannerMessage = .success()
                case .failure(let detail):
                    syncBannerMessage = .failure(detail)
                }
            }
        }
    }
}
