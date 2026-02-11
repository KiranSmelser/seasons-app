import SwiftUI

struct ContentView: View {
    let authService: AuthService

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
    }
}

#Preview {
    ContentView(authService: AuthService())
        .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
