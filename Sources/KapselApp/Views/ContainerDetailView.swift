import SwiftUI
import KapselKit

/// Container details view with tabs for metadata, networking, volumes, exec, and logs
struct ContainerDetailView: View {
    let containerName: String
    var onDismiss: (() -> Void)? = nil

    @State private var detail: ContainerDetail?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // Log content state
    @State private var logs: String = ""
    @State private var isFetchingLogs: Bool = false
    
    // Command exec state
    @State private var execCommandText: String = ""
    @State private var execResult: String = ""
    @State private var isExecutingExec: Bool = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading container configuration...")
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Failed to Load Configuration", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadDetail() }
                    }
                }
            } else if detail != nil {
                detailTabs
            }
        }
        .navigationTitle(containerName)
        .toolbar {
            if let onDismiss {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .onAppear {
            Task {
                await loadDetail()
                fetchLogs()
            }
        }
    }

    @ViewBuilder
    private var detailTabs: some View {
        if let d = detail {
            TabView {
                    // Tab 1: General configurations
                    Form {
                        Section("Metadata") {
                            LabeledContent("ID", value: d.id)
                            LabeledContent("Name", value: d.name)
                            LabeledContent("Image", value: d.image)
                            LabeledContent("Status") {
                                Text(LocalizedStringKey(d.status.capitalized))
                            }
                        }
                        
                        Section("Resources & Platform") {
                            LabeledContent("CPU Limit") {
                                if let cpus = d.cpus {
                                    Text("\(cpus) Cores")
                                } else {
                                    Text("Unlimited")
                                }
                            }
                            LabeledContent("Memory Limit") {
                                if let memory = d.memory {
                                    Text(memory)
                                } else {
                                    Text("Unlimited")
                                }
                            }
                            LabeledContent("Hostname", value: d.hostname ?? "-")
                            LabeledContent("Platform", value: "\(d.os ?? "linux")/\(d.arch ?? "arm64")")
                        }
                    }
                    .formStyle(.grouped)
                    .tabItem {
                        Label("General", systemImage: "info.circle")
                    }
                    
                    // Tab 2: Networking
                    Group {
                        if let ports = d.ports, !ports.isEmpty {
                            Form {
                                LabeledContent("IP Address", value: d.address ?? "Not Assigned / Offline")
                                Section("Port Mappings") {
                                    ForEach(Array(ports.enumerated()), id: \.offset) { _, port in
                                        LabeledContent("\(port.hostPort) → \(port.containerPort)") {
                                            Text(port.protocolType?.uppercased() ?? "TCP")
                                        }
                                    }
                                }
                            }
                            .formStyle(.grouped)
                        } else {
                            ContentUnavailableView("No Port Mappings", systemImage: "network", description: Text("No ports are mapped to the host machine."))
                        }
                    }
                    .tabItem {
                        Label("Networking", systemImage: "network")
                    }
                    
                    // Tab 3: Volumes
                    Group {
                        if let volumes = d.volumes, !volumes.isEmpty {
                            Table(volumes) {
                                TableColumn("Host Path") { vol in
                                    Text(vol.hostPath)
                                }
                                TableColumn("Container Path") { vol in
                                    Text(vol.containerPath)
                                }
                                TableColumn("Access Mode") { vol in
                                    Text(vol.readOnly ? "Read-Only (ro)" : "Read-Write (rw)")
                                }
                            }
                        } else {
                            ContentUnavailableView("No Storage Volumes", systemImage: "folder.badge.minus", description: Text("No external directories are mounted to this container."))
                        }
                    }
                    .tabItem {
                        Label("Volumes", systemImage: "folder.fill")
                    }
                    
                    // Tab 4: Environment Variables
                    Group {
                        if let envs = d.env, !envs.isEmpty {
                            Form {
                                Section {
                                    ForEach(envs, id: \.self) { env in
                                        let parts = env.components(separatedBy: "=")
                                        LabeledContent(parts.first ?? "") {
                                            Text(parts.count > 1 ? parts.dropFirst().joined(separator: "=") : "")
                                        }
                                    }
                                }
                            }
                            .formStyle(.grouped)
                        } else {
                            ContentUnavailableView("No Environment Variables", systemImage: "list.bullet.rectangle", description: Text("No custom environment variables configured."))
                        }
                    }
                    .tabItem {
                        Label("Environment", systemImage: "slider.horizontal.3")
                    }
                    
                    // Tab 5: Command execution (Exec)
                    Form {
                        TextField("Enter command, e.g. uname -a", text: $execCommandText)
                            .disabled(isExecutingExec)

                        Button(action: executeExecCommand) {
                            if isExecutingExec {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Execute", systemImage: "play.fill")
                            }
                        }
                        .disabled(execCommandText.isEmpty || isExecutingExec)

                        Section {
                            TerminalView(content: execResult)
                                .frame(minHeight: 200)
                        }
                    }
                    .formStyle(.grouped)
                    .tabItem {
                        Label("Exec", systemImage: "terminal.fill")
                    }
                    
                    // Tab 6: Console Logs
                    VStack(spacing: 0) {
                        TerminalView(content: logs)
                    }
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button(action: fetchLogs) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .disabled(isFetchingLogs)
                        }
                    }
                    .tabItem {
                        Label("Logs", systemImage: "doc.text.fill")
                    }
            }
        }
    }
    
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await ContainerService.shared.inspectContainer(name: containerName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func fetchLogs() {
        isFetchingLogs = true
        logs = String(localized: "Fetching logs...")
        Task {
            do {
                let fetched = try await ContainerService.shared.getLogs(name: containerName)
                logs = fetched
            } catch {
                logs = String(localized: "Failed to fetch logs: \(error.localizedDescription)")
            }
            isFetchingLogs = false
        }
    }
    
    private func executeExecCommand() {
        guard !execCommandText.isEmpty else { return }
        isExecutingExec = true
        execResult = String(localized: "Executing command: \(execCommandText)...")
        
        Task {
            do {
                let result = try await ContainerService.shared.execCommand(name: containerName, command: execCommandText)
                execResult = result
            } catch {
                execResult = String(localized: "Execution failed: \(error.localizedDescription)")
            }
            isExecutingExec = false
        }
    }
}

#Preview {
    ContainerDetailView(containerName: "web-nginx-server") {}
}
