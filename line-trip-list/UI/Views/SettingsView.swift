import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var vm: SettingsViewModel
    @State private var showLoginSheet: Bool = false
    @State private var currentUserCancellable: AnyCancellable?

    init(nameStore: DisplayNameStore, authService: AuthenticationService) {
        _vm = StateObject(wrappedValue: SettingsViewModel(nameStore: nameStore, authService: authService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("LINE Login")) {
                    if let user = vm.authService.currentUser {
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
                                // debug: show picture URL
                                Text(user.pictureUrl ?? "(nil)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Logout") { vm.authService.logout() }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Login with LINE") { showLoginSheet = true }

                            // Dev helper: simulate login without LINE SDK to verify wiring
                            Button("Simulate Login (dev)") {
                                let fakeAccessToken = "dev-token-\(UUID().uuidString)"
                                let fakeUser = LineUser(userId: "User-Dev-\(Int.random(in: 1000..<9999))", displayName: "Dev User", pictureUrl: "https://picsum.photos/200", statusMessage: nil)
                                vm.authService.login(accessToken: fakeAccessToken, user: fakeUser)
                            }
                            .foregroundColor(.blue)
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .sheet(isPresented: $showLoginSheet) {
                                LoginView()
                                    .environmentObject(vm.authService)
                            }
                        }
                    }
                }

                Section(header: Text("Display name overrides")) {
                    if vm.displayNameOverrides.isEmpty {
                        Text("No overrides set").foregroundColor(.secondary)
                    } else {
                        ForEach(Array(vm.displayNameOverrides.keys.sorted()), id: \.self) { userId in
                            HStack {
                                Text(userId).font(.caption2)
                                TextField("表示名", text: Binding(get: { vm.displayNameOverrides[userId] ?? "" }, set: { vm.setOverride(userId, name: $0) }))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Spacer()
                                Button(role: .destructive) {
                                    vm.removeOverride(userId)
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
        .onChange(of: vm.authService.currentUser?.userId) { newId in
            if newId != nil {
                showLoginSheet = false
            }
            print("[AuthObserve] authService.currentUser changed: \(String(describing: vm.authService.currentUser))")
        }
        .onAppear {
            print("[Settings] currentUser: \(String(describing: vm.authService.currentUser))")
            // Observe changes to the shared AuthenticationService's currentUser
            currentUserCancellable = vm.authService.$currentUser
                .sink { user in
                    print("[AuthObserve] $currentUser sink: \(String(describing: user))")
                }
        }
        .onDisappear {
            currentUserCancellable?.cancel()
            currentUserCancellable = nil
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(nameStore: DisplayNameStore(), authService: AuthenticationService())
    }
}
