import SwiftUI
import KapselKit

/// Entry point of Kapsel macOS GUI Client
@main
struct KapselApp: App {
    @State private var languageManager = AppLanguageManager.shared
    @State private var engineStatus = EngineStatusModel.shared
    @State private var selectedNavigationItem: MainView.NavigationItem? = .dashboard
    @State private var selectedContainerName: String?

    @State private var engineRuntime = EngineRuntimeModel()
    @State private var containersStore = ContainersStore()
    @State private var dashboardStore = DashboardStore()
    @State private var imagesStore = ImagesStore()
    @State private var systemStore = SystemStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView(selection: $selectedNavigationItem, selectedContainerName: $selectedContainerName)
                .frame(minWidth: 1000, minHeight: 650)
                .environment(\.locale, languageManager.locale)
                .environment(languageManager)
                .environment(engineStatus)
                .environment(engineRuntime)
                .environment(containersStore)
                .environment(dashboardStore)
                .environment(imagesStore)
                .environment(systemStore)
                .id(languageManager.selectedLanguage.rawValue)
                .task {
                    await engineStatus.refresh()
                    engineRuntime.startMonitoring()
                    await containersStore.load(showAll: false)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarContent(
                navigationSelection: $selectedNavigationItem,
                selectedContainerName: $selectedContainerName
            )
            .environment(\.locale, languageManager.locale)
            .environment(languageManager)
            .environment(engineStatus)
            .environment(engineRuntime)
            .environment(containersStore)
        } label: {
            Image(systemName: menuBarSymbol)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(\.locale, languageManager.locale)
                .environment(languageManager)
                .environment(engineStatus)
                .id(languageManager.selectedLanguage.rawValue)
                .task {
                    await engineStatus.refresh()
                }
        }
        #endif
    }

    private var menuBarSymbol: String {
        if !engineStatus.isCLIInstalled { return "shippingbox" }
        return engineRuntime.isRunning ? "shippingbox.fill" : "shippingbox"
    }
}
