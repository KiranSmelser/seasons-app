import SwiftUI

enum AppColorScheme: String {
    case system, light, dark
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct ContentView: View {
    let authService: AuthService
    @Binding var syncBannerMessage: SyncBannerMessage?
    var body: some View {
        TabView {
            SeasonalListView(authService: authService)
                .tabItem {
                    Label("In Season", systemImage: "leaf.fill")
                }

            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }

            CarbonDashboardView()
                .tabItem {
                    Label("Impact", systemImage: "chart.bar.fill")
                }
        }
        .tint(.seasonGreen)
        .overlay(alignment: .top) {
            if let message = syncBannerMessage {
                SyncBannerView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + message.duration) {
                            withAnimation {
                                syncBannerMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: syncBannerMessage)
    }
}

#Preview {
    ContentView(authService: AuthService(), syncBannerMessage: .constant(nil))
        .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
