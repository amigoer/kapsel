import SwiftUI
import KapselKit

/// Container details sheet showing general metadata, networking, volumes, environment variables, exec, and logs
struct ContainerDetailView: View {
    let containerName: String
    var onDismiss: () -> Void
    
    @State private var detail: ContainerDetail? = nil
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
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Container Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(containerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading container configuration...")
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Failed to Load Configuration")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadDetail() }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if let d = detail {
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
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Virtual Network & Port Mappings")
                            .font(.headline)
                        
                        LabeledContent("IP Address", value: d.address ?? "Not Assigned / Offline")
                            .padding(.bottom, 8)
                        
                        if let ports = d.ports, !ports.isEmpty {
                            Table(ports) {
                                TableColumn("Host Port") { port in
                                    Text("\(port.hostPort)")
                                }
                                TableColumn("Container Port") { port in
                                    Text("\(port.containerPort)")
                                }
                                TableColumn("Protocol") { port in
                                    Text(port.protocolType?.uppercased() ?? "TCP")
                                }
                            }
                            .border(Color.secondary.opacity(0.15))
                        } else {
                            ContentUnavailableView("No Port Mappings", systemImage: "network", description: Text("No ports are mapped to the host machine."))
                        }
                    }
                    .padding()
                    .tabItem {
                        Label("Networking", systemImage: "network")
                    }
                    
                    // Tab 3: Volumes
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Storage Volume Mounts")
                            .font(.headline)
                        
                        if let volumes = d.volumes, !volumes.isEmpty {
                            Table(volumes) {
                                TableColumn("Host Path") { vol in
                                    Text(vol.hostPath)
                                }
                                TableColumn("Container Path") { vol in
                                    Text(vol.containerPath)
                                }
                                TableColumn("Access Mode") { vol in
                                    if vol.readOnly {
                                        Text("Read-Only (ro)")
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Read-Write (rw)")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .border(Color.secondary.opacity(0.15))
                        } else {
                            ContentUnavailableView("No Storage Volumes", systemImage: "folder.badge.minus", description: Text("No external directories are mounted to this container."))
                        }
                    }
                    .padding()
                    .tabItem {
                        Label("Volumes", systemImage: "folder.fill")
                    }
                    
                    // Tab 4: Environment Variables
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Environment Variables")
                            .font(.headline)
                        
                        if let envs = d.env, !envs.isEmpty {
                            List(envs, id: \.self) { env in
                                let parts = env.components(separatedBy: "=")
                                HStack {
                                    Text(parts.first ?? "")
                                        .fontWeight(.bold)
                                        .frame(width: 180, alignment: .leading)
                                    Divider()
                                    Text(parts.count > 1 ? parts.dropFirst().joined(separator: "=") : "")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .border(Color.secondary.opacity(0.15))
                        } else {
                            ContentUnavailableView("No Environment Variables", systemImage: "list.bullet.rectangle", description: Text("No custom environment variables configured."))
                        }
                    }
                    .padding()
                    .tabItem {
                        Label("Environment", systemImage: "slider.horizontal.3")
                    }
                    
                    // Tab 5: Command execution (Exec)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Execute One-Off Command (Exec)")
                            .font(.headline)
                        
                        HStack {
                            TextField("Enter command, e.g. uname -a", text: $execCommandText)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isExecutingExec)
                            
                            Button(action: executeExecCommand) {
                                if isExecutingExec {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Execute")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(execCommandText.isEmpty || isExecutingExec)
                        }
                        
                        TerminalView(content: execResult)
                    }
                    .padding()
                    .tabItem {
                        Label("Exec", systemImage: "terminal.fill")
                    }
                    
                    // Tab 6: Console Logs
                    VStack(spacing: 0) {
                        HStack {
                            Text("Console Logs (Logs)")
                                .font(.headline)
                            Spacer()
                            Button(action: fetchLogs) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .disabled(isFetchingLogs)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        TerminalView(content: logs)
                            .padding()
                    }
                    .tabItem {
                        Label("Logs", systemImage: "doc.text.fill")
                    }
                }
            }
        }
        .frame(width: 650, height: 500)
        .onAppear {
            Task {
                await loadDetail()
                fetchLogs()
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
