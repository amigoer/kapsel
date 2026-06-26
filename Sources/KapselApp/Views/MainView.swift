import SwiftUI
import KapselKit

/// Main application navigation split layout with Sidebar and Detail hierarchy
struct MainView: View {
    /// Navigation categorizations
    enum NavigationItem: Hashable {
        case dashboard
        case containers
        case images
        case system
        case settings
    }
    
    /// Currently selected navigation page, defaults to Dashboard
    @State private var selectedItem: NavigationItem? = .dashboard
    
    // Engine execution status
    @State private var engineRunning: Bool = false
    @State private var engineLoading: Bool = false
    
    // Polling timer
    @State private var timer: Timer? = nil
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
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
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .navigationTitle("Kapsel")
            
            // Bottom status indicator and control bar
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(LocalizedStringKey(statusText))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: toggleEngine) {
                            if engineLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: engineRunning ? "stop.fill" : "play.fill")
                                    .font(.caption)
                                    .foregroundColor(engineRunning ? .orange : .green)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(engineLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.thinMaterial)
            }
        } detail: {
            switch selectedItem {
            case .dashboard:
                DashboardView()
            case .containers:
                ContainerListView()
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
            }
        }
        .onAppear {
            startStatusPolling()
        }
        .onDisappear {
            stopStatusPolling()
        }
    }
    
    private var statusColor: Color {
        return engineRunning ? .green : .red
    }
    
    private var statusText: String {
        return engineRunning ? "Engine Running" : "Engine Stopped"
    }
    
    private func startStatusPolling() {
        Task {
            await refreshEngineStatus()
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await refreshEngineStatus()
            }
        }
    }
    
    private func stopStatusPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refreshEngineStatus() async {
        do {
            let status = try await SystemService.shared.getSystemStatus()
            engineRunning = status.isRunning
        } catch {
            engineRunning = false
        }
    }
    
    private func toggleEngine() {
        engineLoading = true
        Task {
            do {
                if engineRunning {
                    try await SystemService.shared.stopSystem()
                } else {
                    try await SystemService.shared.startSystem()
                }
                await refreshEngineStatus()
            } catch {
                print("Failed to toggle engine status: \(error)")
            }
            engineLoading = false
        }
    }
}

#Preview {
    MainView()
}
