import SwiftUI
import KapselKit

/// Dashboard view displaying VM resource stats and system control status
struct DashboardView: View {
    @Environment(EngineStatusModel.self) private var engineStatus
    @Environment(EngineRuntimeModel.self) private var engineRuntime
    @Environment(DashboardStore.self) private var store

    @State private var isRefreshing = false

    @State private var quickRunImage: String = ""
    @State private var isQuickRunning: Bool = false
    @State private var runSuccessMessage: String? = nil
    @State private var runErrorMessage: String? = nil
    @FocusState private var isQuickRunFieldFocused: Bool

    @State private var controlErrorMessage: String? = nil
    @State private var controlSuccessMessage: String? = nil

    @State private var buildKitPhase: BuildKitOperationPhase?
    @State private var buildKitInstallProgress: KernelInstallProgress?
    @State private var buildKitFeedback: String?
    @State private var buildKitFeedbackIsError = false
    @State private var showBuildKitAlert = false
    @State private var showUninstallKernelConfirm = false

    var body: some View {
        Form {
            if engineStatus.isChecking {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Detecting container engine...")
                    }
                }
            } else if engineStatus.shouldShowInstallUI {
                Section {
                    EngineSetupBanner {
                        Task {
                            await engineStatus.refresh()
                            await refreshData()
                        }
                    }
                }
            } else if !engineRuntime.isRunning {
                Section {
                    Label {
                        Text("The VM guest engine is currently stopped. Start the engine from System Controls below.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Overview") {
                LabeledContent {
                    Text("\(store.containerCount)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } label: {
                    Label("Containers", systemImage: "shippingbox")
                }

                LabeledContent {
                    Text("\(store.runningContainerCount)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } label: {
                    Label("Running", systemImage: "play.circle")
                }

                LabeledContent {
                    Text("\(store.imageCount)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } label: {
                    Label("Images", systemImage: "photo.stack")
                }
            }

            Section("Resource Utilization") {
                HStack(spacing: 28) {
                    ResourceGaugeRing(
                        title: "CPU Usage",
                        icon: "cpu",
                        value: engineRuntime.isRunning ? 0.12 : 0,
                        tint: .blue,
                        isActive: engineRuntime.isRunning,
                        detailLines: cpuDetailLines
                    )
                    ResourceGaugeRing(
                        title: "Memory Usage",
                        icon: "memorychip",
                        value: engineRuntime.isRunning ? 0.35 : 0,
                        tint: .orange,
                        isActive: engineRuntime.isRunning,
                        detailLines: memoryDetailLines
                    )
                    ResourceGaugeRing(
                        title: "Disk Usage",
                        icon: "internaldrive",
                        value: engineRuntime.isRunning ? 0.58 : 0,
                        tint: .purple,
                        isActive: engineRuntime.isRunning,
                        detailLines: diskDetailLines
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            }

            Section("Quick Deploy Container") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        TextField("Enter OCI image name, e.g. nginx:alpine", text: $quickRunImage)
                            .textFieldStyle(.roundedBorder)
                            .focused($isQuickRunFieldFocused)
                            .disabled(isQuickRunning || !engineRuntime.isRunning || !engineStatus.isCLIInstalled)
                            .onSubmit { quickRunContainer() }

                        Button {
                            quickRunContainer()
                        } label: {
                            if isQuickRunning {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 52)
                            } else {
                                Label("Deploy", systemImage: "play.fill")
                                    .labelStyle(.titleOnly)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(quickRunImage.isEmpty || isQuickRunning || !engineRuntime.isRunning || !engineStatus.isCLIInstalled)
                        .fixedSize(horizontal: true, vertical: false)
                        .keyboardShortcut(.defaultAction)
                    }

                    if !engineRuntime.isRunning && engineStatus.isCLIInstalled {
                        Label("Start the engine before deploying containers.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let success = runSuccessMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let error = runErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("System Controls") {
                LabeledContent {
                    if engineRuntime.isToggling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Toggle("", isOn: engineVMToggle)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .disabled(!engineStatus.isCLIInstalled)
                    }
                } label: {
                    Label("Engine VM", systemImage: "macpro.gen3")
                }

                BuildKitKernelControls(
                    kernelInstalled: store.kernelInstalled,
                    kernelVersion: store.kernelVersion,
                    builderRunning: store.isBuilderRunning,
                    engineRunning: engineRuntime.isRunning,
                    cliInstalled: engineStatus.isCLIInstalled,
                    operationPhase: buildKitPhase,
                    installProgress: buildKitInstallProgress,
                    feedback: buildKitFeedback,
                    feedbackIsError: buildKitFeedbackIsError,
                    needsKernel: !store.kernelInstalled,
                    onToggleBuilder: toggleBuildKit,
                    onInstallKernel: installKernelAndStartBuildKit,
                    onUninstallKernel: { showUninstallKernelConfirm = true }
                )

                LabeledContent {
                    Button("Prune") {
                        pruneLocalImages()
                    }
                    .disabled(!engineRuntime.isRunning || !engineStatus.isCLIInstalled)
                } label: {
                    Label("Unused Images", systemImage: "trash.fill")
                }

                if let msg = controlSuccessMessage {
                    Text(msg)
                        .foregroundStyle(.green)
                }
                if let errMsg = controlErrorMessage {
                    Text(errMsg)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .contentShape(.rect)
        .onTapGesture { isQuickRunFieldFocused = false }
        .navigationTitle("System Monitor")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await refreshData() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .onAppear {
            Task { await refreshData() }
        }
        .onChange(of: engineStatus.installStatus) { _, _ in
            Task { await refreshData() }
        }
        .onChange(of: engineRuntime.isRunning) { _, _ in
            Task { await refreshData() }
        }
        .restoreSidebarFocusWhenLoaded(store.hasLoaded)
        .alert("BuildKit Builder", isPresented: $showBuildKitAlert) {
            if !store.kernelInstalled {
                Button("Install Recommended Kernel") {
                    installKernelAndStartBuildKit()
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let buildKitFeedback, buildKitFeedbackIsError {
                Text(buildKitFeedback)
            }
        }
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
                toggleEngineVM()
            }
        )
    }

    private var cpuDetailLines: [ResourceGaugeDetailLine] {
        guard engineRuntime.isRunning else {
            return [ResourceGaugeDetailLine(label: "Engine Status", value: String(localized: "Offline"))]
        }
        return [
            ResourceGaugeDetailLine(label: "Current Usage", value: "12%"),
            ResourceGaugeDetailLine(label: "VM Allocation", value: "2 cores"),
            ResourceGaugeDetailLine(label: "Engine Status", value: String(localized: "Running"))
        ]
    }

    private var memoryDetailLines: [ResourceGaugeDetailLine] {
        guard engineRuntime.isRunning else {
            return [ResourceGaugeDetailLine(label: "Engine Status", value: String(localized: "Offline"))]
        }
        return [
            ResourceGaugeDetailLine(label: "Current Usage", value: "35%"),
            ResourceGaugeDetailLine(label: "VM Limit", value: "1 GB"),
            ResourceGaugeDetailLine(label: "Available", value: "65%")
        ]
    }

    private var diskDetailLines: [ResourceGaugeDetailLine] {
        guard engineRuntime.isRunning else {
            return [ResourceGaugeDetailLine(label: "Engine Status", value: String(localized: "Offline"))]
        }
        return [
            ResourceGaugeDetailLine(label: "Current Usage", value: "58%"),
            ResourceGaugeDetailLine(label: "VM Disk", value: String(localized: "Guest filesystem")),
            ResourceGaugeDetailLine(label: "Engine Status", value: String(localized: "Running"))
        ]
    }

    private func refreshData() async {
        isRefreshing = true
        await store.refresh(isCLIInstalled: engineStatus.isCLIInstalled)
        isRefreshing = false
    }

    private func quickRunContainer() {
        guard !quickRunImage.isEmpty else { return }
        isQuickRunFieldFocused = false
        isQuickRunning = true
        runErrorMessage = nil
        runSuccessMessage = nil

        Task {
            do {
                try await ContainerService.shared.runContainer(image: quickRunImage, name: nil)
                runSuccessMessage = String(localized: "Container \(quickRunImage) successfully deployed in background.")
                quickRunImage = ""
                await refreshData()
            } catch {
                runErrorMessage = String(localized: "Deployment failed: \(error.localizedDescription)")
            }
            isQuickRunning = false
        }
    }

    private func toggleEngineVM() {
        Task {
            controlErrorMessage = nil
            controlSuccessMessage = nil
            let wasRunning = engineRuntime.isRunning
            await engineRuntime.toggle()
            if wasRunning != engineRuntime.isRunning {
                controlSuccessMessage = engineRuntime.isRunning
                    ? String(localized: "Engine VM successfully started.")
                    : String(localized: "Engine VM successfully stopped.")
            } else if !engineRuntime.isToggling {
                controlErrorMessage = String(localized: "Failed to change engine state.")
            }
            await refreshData()
        }
    }

    private func toggleBuildKit(_ enabled: Bool) {
        guard enabled != store.isBuilderRunning else { return }
        if enabled {
            startBuildKit()
        } else {
            stopBuildKit()
        }
    }

    private func startBuildKit() {
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
                buildKitFeedback = String(localized: "BuildKit environment successfully started.")
                buildKitFeedbackIsError = false
                await refreshData()
            } catch {
                buildKitFeedback = error.localizedDescription
                buildKitFeedbackIsError = true
                showBuildKitAlert = true
            }
        }
    }

    private func stopBuildKit() {
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
                buildKitFeedback = String(localized: "BuildKit builder successfully stopped.")
                buildKitFeedbackIsError = false
                await refreshData()
            } catch {
                buildKitFeedback = error.localizedDescription
                buildKitFeedbackIsError = true
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
                buildKitFeedback = String(localized: "BuildKit environment successfully started.")
                buildKitFeedbackIsError = false
                await refreshData()
            } catch {
                buildKitFeedback = error.localizedDescription
                buildKitFeedbackIsError = true
                showBuildKitAlert = true
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
                await refreshData()
            } catch {
                buildKitFeedback = error.localizedDescription
                buildKitFeedbackIsError = true
            }
        }
    }

    private func pruneLocalImages() {
        Task {
            controlErrorMessage = nil
            controlSuccessMessage = nil
            do {
                try await ImageService.shared.pruneImages()
                controlSuccessMessage = String(localized: "Images successfully pruned.")
                await refreshData()
            } catch {
                controlErrorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(EngineStatusModel.shared)
        .environment(EngineRuntimeModel())
        .environment(DashboardStore())
}
