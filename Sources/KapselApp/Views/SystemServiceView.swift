import SwiftUI
import KapselKit

/// System integration dashboard managing engine VM, BuildKit, DNS routing, registries, and properties
struct SystemServiceView: View {
    // Runtime system VM states
    @State private var engineRunning: Bool = false
    @State private var builderRunning: Bool = false
    @State private var dnsDomain: String = ""
    @State private var systemLogs: String = ""
    @State private var systemProperties: String = ""
    @State private var registryStatus: String = ""
    
    // UI states
    @State private var isLoading: Bool = false
    @State private var isActionRunning: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    // Inputs
    @State private var newDNS: String = ""
    @State private var regURL: String = ""
    @State private var regUser: String = ""
    @State private var regPass: String = ""
    @State private var isLoggingIn: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Services & VM Management")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        Text("Monitor and configure the Apple Silicon local virtualization host VM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: { Task { await refreshAll() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Dashboard grids
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    
                    // Card 1: Engine VM
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Engine VM", systemImage: "macpro.gen3")
                                .font(.headline)
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(engineRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(engineRunning ? LocalizedStringKey("Running") : LocalizedStringKey("Stopped"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("The apple/container CLI runs on top of a lightweight guest Linux VM. Start the engine VM first to load images and containers.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(height: 36, alignment: .top)
                        
                        HStack(spacing: 12) {
                            Button(action: startEngine) {
                                Label("Start Engine", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(engineRunning || isActionRunning)
                            
                            Button(action: stopEngine) {
                                Label("Stop Engine", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .disabled(!engineRunning || isActionRunning)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // Card 2: BuildKit Builder
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("BuildKit Builder", systemImage: "hammer.fill")
                                .font(.headline)
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(builderRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(builderRunning ? LocalizedStringKey("Running") : LocalizedStringKey("Stopped"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Launch a dedicated BuildKit environment to compile OCI container images with high performance using local Dockerfiles.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(height: 36, alignment: .top)
                        
                        Button(action: startBuilder) {
                            Label("Start Builder", systemImage: "bolt.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(builderRunning || !engineRunning || isActionRunning)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // Card 3: DNS configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Sandbox DNS Configuration", systemImage: "network")
                            .font(.headline)
                        
                        HStack {
                            Text("Current Resolution:")
                            Text(dnsDomain.isEmpty ? LocalizedStringKey("Not configured (Default Bridge)") : LocalizedStringKey(dnsDomain))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        
                        HStack {
                            TextField("New DNS domain (e.g. kapsel.local)", text: $newDNS)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Configure") {
                                applyDNS()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newDNS.isEmpty || !engineRunning)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // Card 4: Registry Login
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Private Registry Authorization", systemImage: "lock.shield")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            TextField("Registry Host (e.g. ghcr.io)", text: $regURL)
                                .textFieldStyle(.roundedBorder)
                            TextField("Username", text: $regUser)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Password", text: $regPass)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Login") {
                                loginRegistry()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(regURL.isEmpty || regUser.isEmpty || regPass.isEmpty || isLoggingIn)
                        }
                        
                        Text(registryStatus.isEmpty ? "No registries currently authorized." : registryStatus)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // Properties parameters
                VStack(alignment: .leading, spacing: 12) {
                    Label("Engine VM Properties (Properties)", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    
                    Text(systemProperties.isEmpty ? "No VM properties loaded." : systemProperties)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // System logs TerminalView
                VStack(alignment: .leading, spacing: 12) {
                    Label("Engine VM Diagnostic Logs (System Logs)", systemImage: "doc.plaintext")
                        .font(.headline)
                    
                    TerminalView(content: systemLogs)
                        .frame(height: 250)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
        .onAppear {
            Task {
                await refreshAll()
            }
        }
    }
    
    private func refreshAll() async {
        isLoading = true
        errorMessage = nil
        do {
            let status = try await SystemService.shared.getSystemStatus()
            engineRunning = status.isRunning
            dnsDomain = status.dnsDomain ?? ""
            builderRunning = status.builderRunning
            
            if engineRunning {
                systemProperties = try await SystemService.shared.getProperties()
                registryStatus = try await SystemService.shared.listRegistries()
                systemLogs = try await SystemService.shared.getSystemLogs()
            } else {
                systemProperties = String(localized: "Engine is offline. VM properties are not loaded.")
                registryStatus = String(localized: "Engine is offline. Private registries not loaded.")
                systemLogs = String(localized: "Engine is offline. System logs are empty.")
            }
        } catch {
            engineRunning = false
            systemProperties = String(localized: "Engine is offline. VM properties are not loaded.")
            registryStatus = String(localized: "Engine is offline. Private registries not loaded.")
            systemLogs = String(localized: "Engine is offline. System logs are empty.")
            errorMessage = String(localized: "Failed to load system status: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    private func startEngine() {
        isActionRunning = true
        Task {
            do {
                try await SystemService.shared.startSystem()
                successMessage = String(localized: "Engine VM successfully started.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
            isActionRunning = false
        }
    }
    
    private func stopEngine() {
        isActionRunning = true
        Task {
            do {
                try await SystemService.shared.stopSystem()
                successMessage = String(localized: "Engine VM gracefully stopped.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
            isActionRunning = false
        }
    }
    
    private func startBuilder() {
        isActionRunning = true
        Task {
            do {
                try await SystemService.shared.startBuilder()
                successMessage = String(localized: "BuildKit VM service successfully started.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
            isActionRunning = false
        }
    }
    
    private func applyDNS() {
        Task {
            do {
                try await SystemService.shared.setDefaultDNS(domain: newDNS)
                successMessage = String(localized: "DNS domain configured to: \(newDNS)")
                newDNS = ""
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loginRegistry() {
        isLoggingIn = true
        Task {
            do {
                try await SystemService.shared.loginRegistry(url: regURL, username: regUser, password: regPass)
                successMessage = String(localized: "Registry credentials for \(regURL) configured.")
                regURL = ""
                regUser = ""
                regPass = ""
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoggingIn = false
        }
    }
}

#Preview {
    SystemServiceView()
}
