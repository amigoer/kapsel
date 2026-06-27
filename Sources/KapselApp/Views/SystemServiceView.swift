import SwiftUI
import KapselKit

/// System integration dashboard managing engine VM, BuildKit, DNS routing, registries, and properties
struct SystemServiceView: View {
    @Environment(SystemStore.self) private var store
    @Environment(EngineRuntimeModel.self) private var engineRuntime

    @State private var isRefreshing: Bool = false
    @State private var buildKitPhase: BuildKitOperationPhase?
    @State private var buildKitInstallProgress: KernelInstallProgress?
    @State private var buildKitFeedback: String?
    @State private var buildKitFeedbackIsError = false
    @State private var showUninstallKernelConfirm = false
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
                LabeledContent {
                    if engineRuntime.isToggling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Toggle("", isOn: engineVMToggle)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                } label: {
                    Label("Engine VM", systemImage: "macpro.gen3")
                }

                Text("The apple/container CLI runs on top of a lightweight guest Linux VM. Start the engine VM first to load images and containers.")
            }

            Section("BuildKit Builder") {
                BuildKitKernelServiceSection(
                    kernelInstalled: store.kernelInstalled,
                    kernelVersion: store.kernelVersion,
                    builderRunning: store.builderRunning,
                    engineRunning: store.engineRunning,
                    operationPhase: buildKitPhase,
                    installProgress: buildKitInstallProgress,
                    feedback: buildKitFeedback,
                    feedbackIsError: buildKitFeedbackIsError,
                    needsKernel: !store.kernelInstalled,
                    onToggleBuilder: toggleBuildKit,
                    onInstallKernel: installKernelAndStartBuildKit,
                    onUninstallKernel: { showUninstallKernelConfirm = true }
                )
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
        .restoreSidebarFocusWhenLoaded(store.hasLoaded)
        .confirmationDialog(
            "Uninstall Linux Kernel?",
            isPresented: $showUninstallKernelConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall Kernel", role: .destructive) {
                uninstallKernel()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("BuildKit and container builds will stop working until you install a kernel again. Existing containers are not removed.")
        }
    }

    private var engineVMToggle: Binding<Bool> {
        Binding(
            get: { engineRuntime.isRunning },
            set: { newValue in
                guard newValue != engineRuntime.isRunning, !engineRuntime.isToggling else { return }
                Task {
                    await engineRuntime.toggle()
                    await refreshAll()
                }
            }
        )
    }

    private func refreshAll() async {
        isRefreshing = true
        await store.refresh()
        isRefreshing = false
    }

    private func toggleBuildKit(_ enabled: Bool) {
        guard enabled != store.builderRunning else { return }
        if enabled {
            startBuilder()
        } else {
            stopBuilder()
        }
    }

    private func startBuilder() {
        buildKitPhase = .startingBuilder
        buildKitInstallProgress = nil
        buildKitFeedback = nil
        Task { @MainActor in
            defer {
                buildKitPhase = nil
                buildKitInstallProgress = nil
            }
            do {
                try await SystemService.shared.startBuilder()
                successMessage = String(localized: "BuildKit VM service successfully started.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopBuilder() {
        buildKitPhase = .stoppingBuilder
        buildKitInstallProgress = nil
        buildKitFeedback = nil
        Task { @MainActor in
            defer {
                buildKitPhase = nil
                buildKitInstallProgress = nil
            }
            do {
                try await SystemService.shared.stopBuilder()
                successMessage = String(localized: "BuildKit builder successfully stopped.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func installKernelAndStartBuildKit() {
        buildKitPhase = .installingKernel
        buildKitInstallProgress = nil
        buildKitFeedback = nil
        Task { @MainActor in
            defer {
                buildKitPhase = nil
                buildKitInstallProgress = nil
            }
            do {
                try await KernelService.shared.installRecommended { progress in
                    Task { @MainActor in
                        buildKitInstallProgress = progress.localizedForDisplay
                    }
                }
                buildKitPhase = .startingBuilderAfterKernel
                buildKitInstallProgress = nil
                try await SystemService.shared.startBuilder()
                successMessage = String(localized: "BuildKit VM service successfully started.")
                await refreshAll()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func uninstallKernel() {
        buildKitPhase = .removingKernel
        buildKitInstallProgress = nil
        buildKitFeedback = nil
        Task { @MainActor in
            defer {
                buildKitPhase = nil
                buildKitInstallProgress = nil
            }
            do {
                try await KernelService.shared.removeInstalled { progress in
                    Task { @MainActor in
                        buildKitInstallProgress = progress.localizedForDisplay
                    }
                }
                buildKitFeedback = String(localized: "Linux kernel successfully removed.")
                buildKitFeedbackIsError = false
                await refreshAll()
            } catch {
                buildKitFeedback = error.localizedDescription
                buildKitFeedbackIsError = true
                errorMessage = error.localizedDescription
            }
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
