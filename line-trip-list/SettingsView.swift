import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nameStore: DisplayNameStore
    @State private var showLoginSheet: Bool = false
    @State private var newUserId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("LINE Login")) {
                    if let user = authService.currentUser {
                        HStack {
                            AsyncImage(url: URL(string: user.pictureUrl ?? "")) { img in
                                img.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                            }
                            .frame(width:48,height:48)
                            .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                Text(user.userId)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Logout") { authService.logout() }
                        }
                    } else {
                        Button("Login with LINE") { showLoginSheet = true }
                            .sheet(isPresented: $showLoginSheet) {
                                LoginView()
                                    .environmentObject(authService)
                            }
                    }
                }

                Section(header: Text("Display name overrides")) {
                    if nameStore.overrides.isEmpty {
                        Text("No overrides set").foregroundColor(.secondary)
                    } else {
                        ForEach(Array(nameStore.overrides.keys.sorted()), id: \.self) { userId in
                            HStack {
                                Text(userId).font(.caption2)
                                TextField("表示名", text: nameStore.binding(for: userId))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Spacer()
                                Button(role: .destructive) {
                                    nameStore.removeOverride(for: userId)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onChange(of: authService.currentUser?.userId) { newId in
            // if user logged in, dismiss the login sheet
            if newId != nil {
                showLoginSheet = false
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthenticationService())
            .environmentObject(DisplayNameStore())
    }
}
