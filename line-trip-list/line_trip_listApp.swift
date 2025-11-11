//
//  line_trip_listApp.swift
//  line-trip-list
//
//  Created by 小野拓人 on 2025/10/01.
//

import SwiftUI
import SwiftData
import LineSDK

@main
struct line_trip_listApp: App {
    @StateObject private var authService = AuthenticationService()
    
    init() {
        LoginManager.shared.setup(channelID: Config.LoginAPI.channelID, universalLinkURL: nil)
    }
    
    // Use shared ModelContainer from Persistence.swift which includes our SwiftData models
    var sharedModelContainer: ModelContainer = Persistence.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(authService)
                .onOpenURL { url in
                    // LINE SDK handles the callback automatically
                    _ = LoginManager.shared.application(.shared, open: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
}
