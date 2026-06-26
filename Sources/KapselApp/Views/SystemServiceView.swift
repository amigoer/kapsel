import SwiftUI
import KapselKit

/// System integration dashboard managing engine VM, BuildKit, DNS routing, registries, and properties
struct SystemServiceView: View {
    @Environment(SystemStore.self) private var store

    @State private var isRefreshing: Bool = false
    @State private var isActionRunning: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    @State private var newDNS: String = ""
    @State private var regURL: String = ""
    @State private var regUser: String = ""
    @State private var regPass: String = ""
    @State private var isLoggingIn: Bool = false

    var body: some View {
        Form {
            Section("Engine VM") {
                LabeledContent("Status") {
                    Text(store.engineRunning ? "Running" : "Stopped")
                }

                Text("The apple/container CLI runs on top of a lightweight guest Linux VM. Start the engine VM first to load images and containers.")

                HStack {
                    Button {
                        startEngine()
                    } label: {
                        Label("Start Engine", systemImage: "play.fill")
                    }
                    .disabled(store.engineRunning || isActionRunning)

                    Button {
                        stopEngine()
                    } label: {
                        Label("Stop Engine", systemImage: "stop.fill")
                    }
                    .disabled(!store.engineRunning || isActionRunning)
                }
            }

            Section("BuildKit Builder") {
                LabeledContent("Status") {
                    Text(store.builderRunning ? "Running" : "Stopped")
                }

                Text("Launch a dedicated BuildKit environment to compile OCI container images with high performance using local Dockerfiles.")

                Button {
                    startBuilder()
                } label: {
                    Label("Start Builder", systemImage: "bolt.fill")
                }
                .disabled(store.builderRunning || !store.engineRunning || isActionRunning)
            }

            Section("Sandbox DNS Configuration") {
                LabeledContent("Current Resolution") {
                    Text(store.dnsDomain.isEmpty ? "Not configured (Default Bridge)" : store.dnsDomain)
                }

                TextField("New DNS domain (e.g. kapsel.local)", text: $newDNS)

                Button("Configure") {
                    applyDNS()
                }
                .disabled(newDNS.isEmpty || !store.engineRunning)
            }

            Section("Private Registry Authorization") {
                TextField("Registry Host (e.g. ghcr.io)", text: $regURL)
                TextField("Username", text: $regUser)
                SecureField("Password", text: $regPass)

                Button("Login") {
                    loginRegistry()
                }
                .disabled(regURL.isEmpty || regUser.isEmpty || regPass.isEmpty || isLoggingIn)

                Text(store.registryStatus.isEmpty ? "No registries currently authorized." : store.registryStatus)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Section("Engine VM Properties") {
                Text(store.systemProperties.isEmpty ? "No VM properties loaded." : store.systemProperties)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Engine VM Diagnostic Logs") {
                TerminalView(content: store.systemLogs)
                    .frame(minHeight: 200)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Services & VM Management")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
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
            Task { await refreshAll() }
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        await store.refresh()
        isRefreshing = false
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
        .environment(SystemStore())
}
