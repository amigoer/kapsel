import SwiftUI
import KapselKit

/// Main application navigation split layout with Sidebar and Detail hierarchy
struct MainView: View {
    @Environment(EngineStatusModel.self) private var engineStatus
    @Environment(EngineRuntimeModel.self) private var engineRuntime

    enum NavigationItem: Hashable {
        case dashboard
        case containers
        case images
        case system
        case settings
    }

    @Binding var selection: NavigationItem?
    @Binding var selectedContainerName: String?
    @FocusState private var sidebarFocused: Bool

    /// Fixed sidebar width keeps it identical across two-/three-column tab switches.
    private let sidebarWidth: CGFloat = 264

    var body: some View {
        Group {
            if selection == .containers {
                // Three columns: sidebar + container list + detail
                NavigationSplitView {
                    sidebarColumn
                } content: {
                    ContainerListColumn(selection: $selectedContainerName)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
                } detail: {
                    containerDetail
                }
            } else {
                // Two columns: sidebar + detail
                NavigationSplitView {
                    sidebarColumn
                } detail: {
                    detailRoot
                }
            }
        }
        .environment(\.restoreSidebarFocus) { @Sendable in
            Task { @MainActor in
                sidebarFocused = true
            }
        }
        .onAppear {
            engineRuntime.startMonitoring()
            sidebarFocused = true
        }
        .onChange(of: selection) { _, newValue in
            if newValue != .containers {
                selectedContainerName = nil
            }
            sidebarFocused = true
        }
        .onChange(of: engineStatus.installStatus) { _, _ in
            Task { await engineRuntime.refresh() }
        }
    }

    private var sidebarColumn: some View {
        sidebar
            .focusSection()
            .focused($sidebarFocused)
            .navigationSplitViewColumnWidth(sidebarWidth)
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Management") {
                sidebarRow("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent", item: .dashboard)
                sidebarRow("Containers", systemImage: "shippingbox.fill", item: .containers)
                sidebarRow("Images", systemImage: "photo.stack", item: .images)
            }

            Section("System") {
                sidebarRow("Services", systemImage: "server.rack", item: .system)
                sidebarRow("Settings", systemImage: "gearshape", item: .settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EngineStatusBar(
                statusText: statusText,
                statusSubtitle: statusSubtitle,
                statusColor: statusColor,
                engineRunning: engineRuntime.isRunning,
                isLoading: engineRuntime.isToggling,
                isDisabled: engineStatus.isChecking || !engineStatus.isCLIInstalled,
                onToggle: { Task { await engineRuntime.toggle() } }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("Kapsel")
    }

    private func sidebarRow(_ title: LocalizedStringKey, systemImage: String, item: NavigationItem) -> some View {
        Label(title, systemImage: systemImage)
            .tag(item)
    }

    @ViewBuilder
    private var detailRoot: some View {
        switch selection {
        case .dashboard:
            DashboardView()
        case .images:
            ImageListView()
        case .system:
            SystemServiceView()
        case .settings:
            SettingsView()
        case .containers, nil:
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "sidebar.left",
                description: Text("Please select a management page from the sidebar")
            )
        }
    }

    @ViewBuilder
    private var containerDetail: some View {
        if let selectedContainerName {
            ContainerDetailView(containerName: selectedContainerName)
                .id(selectedContainerName)
        } else {
            ContentUnavailableView(
                "Select a Container",
                systemImage: "shippingbox",
                description: Text("Choose a container from the list to view details.")
            )
        }
    }

    private var statusColor: Color {
        if engineStatus.isChecking { return .secondary }
        if engineStatus.shouldShowInstallUI { return .orange }
        return engineRuntime.isRunning ? .green : .red
    }

    private var statusText: String {
        if engineStatus.isChecking { return "Detecting Engine..." }
        if engineStatus.shouldShowInstallUI { return "Engine Not Installed" }
        return engineRuntime.isRunning ? "Engine Running" : "Engine Stopped"
    }

    private var statusSubtitle: String {
        if engineStatus.isChecking { return "Checking container CLI installation" }
        if engineStatus.shouldShowInstallUI { return "Install the engine to get started" }
        return engineRuntime.isRunning ? "Container API is online" : "Tap play to start the engine"
    }
}

#Preview {
    MainView(selection: .constant(.dashboard), selectedContainerName: .constant(nil))
        .environment(EngineStatusModel.shared)
        .environment(EngineRuntimeModel())
}
