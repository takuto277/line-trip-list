import SwiftUI
import SwiftData

struct RootTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nameStore: DisplayNameStore
    // Expect MessagesViewModel and repository to be injected at App level
    @EnvironmentObject var messagesVM: MessagesViewModel
    @EnvironmentObject var messageRepo: LineMessageService

    var body: some View {
        TabView {
            MessageTabView()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }

            LinksView(repository: messageRepo)
                .tabItem {
                    Label("Links", systemImage: "link")
                }

            SettingsView(nameStore: nameStore, authService: authService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(authService)
        .environmentObject(nameStore)
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
