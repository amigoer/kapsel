import SwiftUI
import AppKit
import KapselKit

/// Content of the always-on menu bar item (OrbStack-style).
struct MenuBarContent: View {
    @Environment(EngineStatusModel.self) private var engineStatus
    @Environment(EngineRuntimeModel.self) private var engineRuntime
    @Environment(ContainersStore.self) private var containersStore
    @Environment(\.openWindow) private var openWindow

    @Binding var navigationSelection: MainView.NavigationItem?
    @Binding var selectedContainerName: String?

    private let maxListed = 8

    var body: some View {
        Button("Open Kapsel") { openMainWindow() }
            .keyboardShortcut("n")

        Divider()

        Text(statusText)

        if engineStatus.isCLIInstalled {
            Button(engineRuntime.isRunning ? "Stop Engine" : "Start Engine") {
                Task { await engineRuntime.toggle() }
            }
            .disabled(engineRuntime.isToggling)
        }

        if engineStatus.isCLIInstalled, !containersStore.containers.isEmpty {
            Divider()

            Section("Containers") {
                ForEach(Array(containersStore.containers.prefix(maxListed))) { container in
                    Menu {
                        Button("Open") { open(container) }
                        Divider()
                        Button("Start") { perform(container) { try await ContainerService.shared.startContainer(name: $0) } }
                            .disabled(container.status == .running)
                        Button("Stop") { perform(container) { try await ContainerService.shared.stopContainer(name: $0) } }
                            .disabled(container.status != .running)
                    } label: {
                        Label(container.name, systemImage: container.status == .running ? "circle.fill" : "circle")
                    }
                }
            }

            if containersStore.containers.count > maxListed {
                Button("Show All Containers…") {
                    navigationSelection = .containers
                    openMainWindow()
                }
            }
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        Button("Quit Kapsel") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: LocalizedStringKey {
        if engineStatus.isChecking { return "Detecting Engine..." }
        if engineStatus.shouldShowInstallUI { return "Engine Not Installed" }
        return engineRuntime.isRunning ? "Engine Running" : "Engine Stopped"
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }

    private func open(_ container: Container) {
        selectedContainerName = container.name
        navigationSelection = .containers
        openMainWindow()
    }

    private func perform(_ container: Container, _ action: @escaping (String) async throws -> Void) {
        Task {
            try? await action(container.name)
            await containersStore.load(showAll: false)
        }
    }
}
