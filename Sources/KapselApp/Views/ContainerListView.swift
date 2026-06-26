import SwiftUI
import KapselKit

/// Container list and lifecycle management view
struct ContainerListView: View {
    @State private var containers: [Container] = []
    @State private var searchText: String = ""
    @State private var showAll: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // Selected container ID for selection and context menu responses
    @State private var selectedContainerId: String? = nil
    
    // Selected container for console logs sheet
    @State private var selectedContainerForLogs: Container? = nil
    @State private var containerLogs: String = ""
    @State private var isFetchingLogs: Bool = false
    
    // Selected container for detail sheet
    @State private var selectedContainerForDetail: Container? = nil
    
    // Create form sheet visibility
    @State private var isShowingCreateSheet: Bool = false
    
    // Polling timer
    @State private var timer: Timer? = nil
    
    var filteredContainers: [Container] {
        containers.filter { container in
            let matchesSearch = searchText.isEmpty || 
                container.name.localizedCaseInsensitiveContains(searchText) || 
                container.image.localizedCaseInsensitiveContains(searchText)
            return matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Action toolbar
            HStack(spacing: 16) {
                Text("Container Instances")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by name or image...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 250)
                
                // Show All Toggle
                Toggle("Show All Containers", isOn: $showAll)
                    .onChange(of: showAll) { _, _ in
                        Task { await loadContainers() }
                    }
                
                Spacer()
                
                Button(action: { isShowingCreateSheet = true }) {
                    Label("Deploy Container", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button(action: { Task { await loadContainers() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Containers list table
            if isLoading && containers.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading container list...")
                    Spacer()
                }
            } else if filteredContainers.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        "No Containers Found",
                        systemImage: "shippingbox",
                        description: Text(searchText.isEmpty ? "Click 'Deploy Container' at the top right to create your first container instance." : "Try changing search terms")
                    )
                    Spacer()
                }
            } else {
                Table(filteredContainers, selection: $selectedContainerId) {
                    TableColumn("Container ID") { container in
                        Text(container.containerID.prefix(12))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 80, ideal: 100, max: 120)
                    
                    TableColumn("Name") { container in
                        Button(action: { selectedContainerForDetail = container }) {
                            Text(container.name)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .width(min: 120, ideal: 150, max: 200)
                    
                    TableColumn("Image") { container in
                        Text(container.image)
                            .lineLimit(1)
                    }
                    .width(min: 150, ideal: 200, max: 300)
                    
                    TableColumn("Status") { container in
                        StatusBadge(status: container.status)
                    }
                    .width(min: 80, ideal: 100, max: 120)
                    
                    TableColumn("IP Address") { container in
                        Text(container.address ?? "-")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 90, ideal: 110, max: 140)
                    
                    TableColumn("Platform") { container in
                        Text("\(container.os)/\(container.arch)")
                            .foregroundColor(.secondary)
                    }
                    .width(min: 90, ideal: 110, max: 140)
                    
                    TableColumn("Actions") { container in
                        HStack(spacing: 12) {
                            Button(action: { showLogs(container) }) {
                                Image(systemName: "terminal")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .help("View Logs")
                            
                            if container.status == .running {
                                Button(action: { stopContainer(container) }) {
                                    Image(systemName: "stop.fill")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                                .help("Stop Gracefully")
                                
                                Button(action: { killContainer(container) }) {
                                    Image(systemName: "lightning.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Force Kill")
                            } else {
                                Button(action: { startContainer(container) }) {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.plain)
                                .help("Start")
                            }
                            
                            Button(action: { deleteContainer(container) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(container.status == .running)
                            .opacity(container.status == .running ? 0.4 : 1.0)
                            .help("Delete")
                        }
                    }
                    .width(min: 110, ideal: 130, max: 150)
                }
                .contextMenu {
                    if let selectedId = selectedContainerId, let container = containers.first(where: { $0.id == selectedId }) {
                        Button("Start") { startContainer(container) }
                            .disabled(container.status == .running)
                        Button("Stop") { stopContainer(container) }
                            .disabled(container.status != .running)
                        Button("Force Kill (Kill)") { killContainer(container) }
                            .disabled(container.status != .running)
                        Divider()
                        Button("View Console Logs") { showLogs(container) }
                        Button("View Container Details") { selectedContainerForDetail = container }
                        Divider()
                        Button("Delete Container") { deleteContainer(container) }
                            .disabled(container.status == .running)
                    } else {
                        Text("No container selected")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert("Operation Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            ContainerCreateView(onDismiss: {
                isShowingCreateSheet = false
                Task { await loadContainers() }
            })
        }
        .sheet(item: $selectedContainerForLogs) { container in
            VStack(spacing: 0) {
                HStack {
                    Text("Container Logs - \(container.name)")
                        .font(.headline)
                    Spacer()
                    
                    Button(action: { fetchLogs(for: container) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetchingLogs)
                    .padding(.trailing, 8)
                    
                    Button("Close") {
                        selectedContainerForLogs = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                TerminalView(content: containerLogs)
                    .padding()
            }
            .frame(width: 700, height: 450)
            .onAppear {
                fetchLogs(for: container)
            }
        }
        .sheet(item: $selectedContainerForDetail) { container in
            ContainerDetailView(containerName: container.name) {
                selectedContainerForDetail = nil
                Task { await loadContainers() }
            }
        }
        .onAppear {
            Task { await loadContainers() }
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                do {
                    let fetched = try await ContainerService.shared.fetchContainers(showAll: showAll)
                    await MainActor.run {
                        self.containers = fetched
                    }
                } catch {
                    print("Failed to poll containers: \(error)")
                }
            }
        }
    }
    
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func loadContainers() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await ContainerService.shared.fetchContainers(showAll: showAll)
            containers = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func startContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.startContainer(name: container.name)
                await loadContainers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func stopContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.stopContainer(name: container.name)
                await loadContainers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func killContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.killContainer(name: container.name)
                await loadContainers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func deleteContainer(_ container: Container) {
        let alert = NSAlert()
        alert.messageText = "Confirm Deletion"
        alert.informativeText = "Are you sure you want to delete container: \(container.name)? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task {
                do {
                    try await ContainerService.shared.deleteContainer(name: container.name)
                    await loadContainers()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func showLogs(_ container: Container) {
        selectedContainerForLogs = container
    }
    
    private func fetchLogs(for container: Container) {
        isFetchingLogs = true
        containerLogs = "Fetching logs..."
        Task {
            do {
                let logs = try await ContainerService.shared.getLogs(name: container.name)
                containerLogs = logs
            } catch {
                containerLogs = "Failed to fetch logs: \(error.localizedDescription)"
            }
            isFetchingLogs = false
        }
    }
}
