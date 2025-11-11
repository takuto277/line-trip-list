import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var displayNameOverride: String = UserDefaults.standard.string(forKey: "displayNameOverride") ?? ""
    @State private var isLoggedIn: Bool = false
    @State private var showLoginSheet: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("LINE Login")) {
                    if let user = authService.currentUser {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Logged in as \(user.displayName)")
                                .foregroundColor(.secondary)
                        }

                        Button("Logout") { authService.logout() }
                    } else {
                        Button("Login with LINE") { showLoginSheet = true }
                            .sheet(isPresented: $showLoginSheet) {
                                LoginView()
                                    .environmentObject(authService)
                            }
                    }
                }

                Section(header: Text("Display name override")) {
                    TextField("表示名を上書きする", text: $displayNameOverride)
                    Button("保存") {
                        UserDefaults.standard.set(displayNameOverride, forKey: "displayNameOverride")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
