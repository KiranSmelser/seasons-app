import SwiftUI
import SwiftData
import GoogleSignIn
import os

@main
struct SeasonsApp: App {
    @State private var authService = AuthService()
    @State private var syncBannerMessage: SyncBannerMessage?
    @State private var subscriptionService = SubscriptionService()
    @AppStorage("colorSchemePreference") private var colorSchemePref = AppColorScheme.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let syncService: SyncService
    @State private var syncCoordinator: SyncCoordinator
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "SeasonsApp")

    init() {
        let container = Self.makeModelContainer()
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
                .environment(subscriptionService)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear { applyColorScheme(colorSchemePref) }
                .onChange(of: colorSchemePref) { _, newValue in applyColorScheme(newValue) }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let user = authService.currentUser {
                Task {
                    await subscriptionService.checkEntitlement()
                    guard subscriptionService.isPro else { return }
                    let result = await syncService.performSync(userId: user.id)
                    showBanner(for: result)
                }
            }
        }
        .onChange(of: authService.isSignedIn) { wasSignedIn, isNowSignedIn in
            if !wasSignedIn && isNowSignedIn, let user = authService.currentUser {
                Task {
                    await subscriptionService.checkEntitlement()
                    guard subscriptionService.isPro else { return }
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
                        logger.error("Sign-out cleanup failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }

    private func applyColorScheme(_ pref: String) {
        let style: UIUserInterfaceStyle
        switch AppColorScheme(rawValue: pref) {
        case .light: style = .light
        case .dark: style = .dark
        default: style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
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

    /// Creates the SwiftData ModelContainer, recovering from schema-migration failures.
    /// Falls back to an in-memory store only as a last resort so the app never crashes on startup.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([CarbonLog.self, Favorite.self, PendingSyncDeletion.self])
        let config = ModelConfiguration(schema: schema)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Schema changed — wipe the on-disk store and retry once.
        let storeURL = config.url
        for ext in ["store", "store-shm", "store-wal"] {
            let url = storeURL.deletingPathExtension().appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: url)
        }

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Last resort: in-memory only. Data won't survive this session,
        // but the app stays functional rather than crashing.
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [memConfig]) else {
            fatalError("Failed to initialise even an in-memory ModelContainer — this should never happen.")
        }
        return container
    }
}
