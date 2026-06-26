import SwiftUI
import KapselKit

/// Entry point of Kapsel macOS GUI Client
@main
struct KapselApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
