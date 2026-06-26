import SwiftUI
import KapselKit

/// Dashboard view displaying VM resource stats and system control status
struct DashboardView: View {
    @Environment(EngineStatusModel.self) private var engineStatus
    @Environment(DashboardStore.self) private var store

    @State private var isRefreshing = false

    @State private var quickRunImage: String = ""
    @State private var isQuickRunning: Bool = false
    @State private var runSuccessMessage: String? = nil
    @State private var runErrorMessage: String? = nil

    @State private var controlErrorMessage: String? = nil
    @State private var controlSuccessMessage: String? = nil

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
            } else if !store.isVMRunning {
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
                HStack(spacing: 0) {
                    MetricTile(icon: "shippingbox", value: store.containerCount, title: "Containers", tint: .blue)
                    Divider().frame(height: 48)
                    MetricTile(icon: "play.circle", value: store.runningContainerCount, title: "Running", tint: .green)
                    Divider().frame(height: 48)
                    MetricTile(icon: "photo.stack", value: store.imageCount, title: "Images", tint: .purple)
                }
                .padding(.vertical, 8)
            }

            Section("Resource Utilization") {
                HStack(spacing: 0) {
                    ResourceGauge(title: "CPU Usage", value: store.isVMRunning ? 0.12 : 0, tint: .blue)
                    ResourceGauge(title: "Memory Usage", value: store.isVMRunning ? 0.35 : 0, tint: .orange)
                    ResourceGauge(title: "Disk Usage", value: store.isVMRunning ? 0.58 : 0, tint: .purple)
                }
                .padding(.vertical, 8)
            }

            Section("Quick Deploy Container") {
                TextField("Enter OCI image name, e.g. nginx:alpine", text: $quickRunImage)
                    .disabled(isQuickRunning || !store.isVMRunning || !engineStatus.isCLIInstalled)

                Button {
                    quickRunContainer()
                } label: {
                    if isQuickRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Deploy", systemImage: "play.fill")
                    }
                }
                .disabled(quickRunImage.isEmpty || isQuickRunning || !store.isVMRunning || !engineStatus.isCLIInstalled)

                if let success = runSuccessMessage {
                    Text(success)
                        .foregroundStyle(.green)
                }
                if let error = runErrorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("System Controls") {
                LabeledContent {
                    Button(store.isVMRunning ? "Stop" : "Start") {
                        toggleEngineVM()
                    }
                    .disabled(!engineStatus.isCLIInstalled)
                } label: {
                    Label("Engine VM", systemImage: "macpro.gen3")
                }

                LabeledContent {
                    Button(store.isBuilderRunning ? "Running" : "Start") {
                        startBuildKit()
                    }
                    .disabled(store.isBuilderRunning || !store.isVMRunning || !engineStatus.isCLIInstalled)
                } label: {
                    Label("BuildKit Builder", systemImage: "hammer.fill")
                }

                LabeledContent {
                    Button("Prune") {
                        pruneLocalImages()
                    }
                    .disabled(!store.isVMRunning || !engineStatus.isCLIInstalled)
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
    }

    private func refreshData() async {
        isRefreshing = true
        await store.refresh(isCLIInstalled: engineStatus.isCLIInstalled)
        isRefreshing = false
    }

    private func quickRunContainer() {
        guard !quickRunImage.isEmpty else { return }
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
            do {
                if store.isVMRunning {
                    try await SystemService.shared.stopSystem()
                    controlSuccessMessage = String(localized: "Engine VM successfully stopped.")
                } else {
                    try await SystemService.shared.startSystem()
                    controlSuccessMessage = String(localized: "Engine VM successfully started.")
                }
                await refreshData()
            } catch {
                controlErrorMessage = error.localizedDescription
            }
        }
    }

    private func startBuildKit() {
        Task {
            controlErrorMessage = nil
            controlSuccessMessage = nil
            do {
                try await SystemService.shared.startBuilder()
                controlSuccessMessage = String(localized: "BuildKit environment successfully started.")
                await refreshData()
            } catch {
                controlErrorMessage = error.localizedDescription
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

/// A single Overview metric (icon, large animated number, caption).
private struct MetricTile: View {
    let icon: String
    let value: Int
    let title: LocalizedStringKey
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A native circular gauge for a resource utilization percentage.
private struct ResourceGauge: View {
    let title: LocalizedStringKey
    let value: Double
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 8) {
            Gauge(value: value) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView()
        .environment(EngineStatusModel.shared)
        .environment(DashboardStore())
}
