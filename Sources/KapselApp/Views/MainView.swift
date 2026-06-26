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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if selection == .containers {
                containersLayout
            } else {
                simpleLayout
            }
        }
        .onAppear {
            engineRuntime.startMonitoring()
        }
        .onChange(of: selection) { _, _ in
            columnVisibility = .all
            if selection != .containers {
                selectedContainerName = nil
            }
        }
        .onChange(of: engineStatus.installStatus) { _, _ in
            Task { await engineRuntime.refresh() }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Management") {
                NavigationLink(value: NavigationItem.dashboard) {
                    Label("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent")
                }
                NavigationLink(value: NavigationItem.containers) {
                    Label("Containers", systemImage: "shippingbox.fill")
                }
                NavigationLink(value: NavigationItem.images) {
                    Label("Images", systemImage: "photo.stack")
                }
            }

            Section("System") {
                NavigationLink(value: NavigationItem.system) {
                    Label("Services", systemImage: "server.rack")
                }
                NavigationLink(value: NavigationItem.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .navigationTitle("Kapsel")
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
        }
    }

    private var containersLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            ContainerListColumn(selection: $selectedContainerName)
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            ZStack {
                containersDetail
                    .id(selectedContainerName)
                    .transition(.opacity)
            }
            .animation(.smooth(duration: 0.22), value: selectedContainerName)
        }
    }

    @ViewBuilder
    private var containersDetail: some View {
        if let selectedContainerName {
            ContainerDetailView(containerName: selectedContainerName)
        } else {
            ContentUnavailableView(
                "Select a Container",
                systemImage: "shippingbox",
                description: Text("Choose a container from the list to view details.")
            )
        }
    }

    private var simpleLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            ZStack {
                simpleDetail
                    .id(selection)
                    .transition(.opacity)
            }
            .animation(.smooth(duration: 0.22), value: selection)
        }
    }

    @ViewBuilder
    private var simpleDetail: some View {
        switch selection {
        case .dashboard:
            DashboardView()
        case .images:
            ImageListView()
        case .system:
            SystemServiceView()
        case .settings:
            SettingsView()
        case nil:
            ContentUnavailableView(
                "No Item Selected",
                systemImage: "sidebar.left",
                description: Text("Please select a management page from the sidebar")
            )
        case .containers:
            EmptyView()
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
