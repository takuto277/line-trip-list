import SwiftUI
import SwiftData

struct RootTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var lineService = LineMessageService()

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }

            LinksView(lineService: lineService)
                .tabItem {
                    Label("Links", systemImage: "link")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(authService)
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
