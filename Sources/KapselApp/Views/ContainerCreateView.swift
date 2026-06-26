import SwiftUI
import KapselKit

/// Deployment creation form view
struct ContainerCreateView: View {
    var onDismiss: () -> Void
    
    // General configurations
    @State private var imageName: String = ""
    @State private var containerName: String = ""
    @State private var runCommand: String = ""
    
    // Resource constraints
    @State private var cpus: Int = 4
    @State private var selectedMemory: String = "1G"
    let memoryOptions = ["512M", "1G", "2G", "4G", "8G", "16G"]
    
    // Network configurations
    @State private var hostname: String = ""
    @State private var portMappings: [PortMappingInput] = []
    
    // Volume configurations
    @State private var volumeMounts: [VolumeMountInput] = []
    
    // Environment configurations
    @State private var envVariables: [EnvInput] = []
    
    // Advanced options
    @State private var entrypoint: String = ""
    @State private var autoRemove: Bool = false
    @State private var runInBackground: Bool = true
    
    // States
    @State private var isDeploying: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deploy New Container")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure image details and sandbox virtualization parameters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Forms
            Form {
                // 1. General configurations
                Section("General Configurations") {
                    HStack {
                        Text("Image Name *")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. nginx:alpine or library/ubuntu:latest", text: $imageName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Container Name")
                            .frame(width: 100, alignment: .leading)
                        TextField("Optional, randomly generated if empty", text: $containerName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Start Command")
                            .frame(width: 100, alignment: .leading)
                        TextField("Optional command overrides, e.g. sleep 3600", text: $runCommand)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // 2. Resource constraints
                Section("Resource Constraints") {
                    Stepper(value: $cpus, in: 1...32) {
                        HStack {
                            Text("Allocated CPU:")
                            Text("\(cpus) Cores").fontWeight(.bold)
                        }
                    }
                    
                    Picker("Memory Limit:", selection: $selectedMemory) {
                        ForEach(memoryOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 3. Port mapping configurations
                Section(header: HStack {
                    Text("Port Mappings")
                    Spacer()
                    Button(action: addPortMapping) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }) {
                    HStack {
                        Text("Hostname")
                            .frame(width: 100, alignment: .leading)
                        TextField("Optional hostname inside container", text: $hostname)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    ForEach($portMappings) { $mapping in
                        HStack {
                            TextField("Host Port (e.g. 8080)", text: $mapping.hostPort)
                                .textFieldStyle(.roundedBorder)
                            Text("➔")
                            TextField("Container Port (e.g. 80)", text: $mapping.containerPort)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: { removePortMapping(id: mapping.id) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // 4. Volume mount configurations
                Section(header: HStack {
                    Text("Storage Volume Mounts")
                    Spacer()
                    Button(action: addVolumeMount) {
                        Image(systemName: "plus.circle.fill")
                        Text("Mount Directory")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }) {
                    ForEach($volumeMounts) { $vol in
                        VStack(spacing: 8) {
                            HStack {
                                TextField("Host Folder Path", text: $vol.host)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse...") {
                                    selectHostPath(for: vol.id)
                                }
                            }
                            
                            HStack {
                                TextField("Container Destination Path", text: $vol.container)
                                    .textFieldStyle(.roundedBorder)
                                Toggle("Read-Only", isOn: $vol.readOnly)
                                
                                Spacer()
                                
                                Button(action: { removeVolumeMount(id: vol.id) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 5. Environment variables
                Section(header: HStack {
                    Text("Environment Variables")
                    Spacer()
                    Button(action: addEnvVariable) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Variable")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }) {
                    ForEach($envVariables) { $env in
                        HStack {
                            TextField("KEY", text: $env.key)
                                .textFieldStyle(.roundedBorder)
                            Text("=")
                            TextField("VALUE", text: $env.value)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: { removeEnvVariable(id: env.id) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // 6. Advanced configurations
                Section("Advanced Options") {
                    HStack {
                        Text("Entrypoint")
                            .frame(width: 100, alignment: .leading)
                        TextField("Optional ENTRYPOINT overrides", text: $entrypoint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Toggle("Auto Remove (--rm)", isOn: $autoRemove)
                    Toggle("Run in Background (Detach)", isOn: $runInBackground)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Footer actions
            HStack {
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                }
                
                Spacer()
                
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isDeploying)
                
                Button(action: deployContainer) {
                    if isDeploying {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Deploy")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(imageName.isEmpty || isDeploying)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 680)
    }
    
    private func addPortMapping() {
        portMappings.append(PortMappingInput())
    }
    
    private func removePortMapping(id: UUID) {
        portMappings.removeAll { $0.id == id }
    }
    
    private func addVolumeMount() {
        volumeMounts.append(VolumeMountInput())
    }
    
    private func removeVolumeMount(id: UUID) {
        volumeMounts.removeAll { $0.id == id }
    }
    
    private func selectHostPath(for id: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = String(localized: "Select Host Mount Directory")
        if panel.runModal() == .OK {
            if let path = panel.url?.path, let index = volumeMounts.firstIndex(where: { $0.id == id }) {
                volumeMounts[index].host = path
            }
        }
    }
    
    private func addEnvVariable() {
        envVariables.append(EnvInput())
    }
    
    private func removeEnvVariable(id: UUID) {
        envVariables.removeAll { $0.id == id }
    }
    
    private func deployContainer() {
        isDeploying = true
        errorMessage = nil
        
        let ports = portMappings
            .filter { !$0.hostPort.isEmpty && !$0.containerPort.isEmpty }
            .map { "\($0.hostPort):\($0.containerPort)" }
        
        let volumes = volumeMounts
            .filter { !$0.host.isEmpty && !$0.container.isEmpty }
            .map { "\($0.host):\($0.container)\($0.readOnly ? ":ro" : "")" }
        
        let envs = envVariables
            .filter { !$0.key.isEmpty }
            .map { "\($0.key)=\($0.value)" }
        
        Task {
            do {
                if runInBackground {
                    try await ContainerService.shared.runContainer(
                        image: imageName,
                        name: containerName.isEmpty ? nil : containerName,
                        cpus: cpus,
                        memory: selectedMemory,
                        env: envs.isEmpty ? nil : envs,
                        ports: ports.isEmpty ? nil : ports,
                        volumes: volumes.isEmpty ? nil : volumes,
                        hostname: hostname.isEmpty ? nil : hostname,
                        entrypoint: entrypoint.isEmpty ? nil : entrypoint,
                        autoRemove: autoRemove,
                        detach: true
                    )
                } else {
                    try await ContainerService.shared.createContainer(
                        image: imageName,
                        name: containerName.isEmpty ? nil : containerName,
                        cpus: cpus,
                        memory: selectedMemory,
                        env: envs.isEmpty ? nil : envs,
                        ports: ports.isEmpty ? nil : ports,
                        volumes: volumes.isEmpty ? nil : volumes,
                        hostname: hostname.isEmpty ? nil : hostname,
                        entrypoint: entrypoint.isEmpty ? nil : entrypoint,
                        autoRemove: autoRemove
                    )
                }
                
                await MainActor.run {
                    isDeploying = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(localized: "Failed to deploy container: \(error.localizedDescription)")
                    isDeploying = false
                }
            }
        }
    }
}

struct PortMappingInput: Identifiable {
    let id = UUID()
    var hostPort: String = ""
    var containerPort: String = ""
}

struct VolumeMountInput: Identifiable {
    let id = UUID()
    var host: String = ""
    var container: String = ""
    var readOnly: Bool = false
}

struct EnvInput: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}
