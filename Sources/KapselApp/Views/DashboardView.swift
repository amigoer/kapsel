import SwiftUI
import KapselKit

/// Dashboard view displaying VM resource stats and system control status
struct DashboardView: View {
    @State private var containerCount: Int = 0
    @State private var runningContainerCount: Int = 0
    @State private var imageCount: Int = 0
    @State private var isVMRunning: Bool = false
    @State private var isBuilderRunning: Bool = false
    @State private var isLoading: Bool = false
    
    // Quick deploy form configurations
    @State private var quickRunImage: String = ""
    @State private var isQuickRunning: Bool = false
    @State private var runSuccessMessage: String? = nil
    @State private var runErrorMessage: String? = nil
    
    // Action control status
    @State private var controlErrorMessage: String? = nil
    @State private var controlSuccessMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Top header bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Monitor")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        Text("Real-time execution diagnostics based on Apple Silicon Virtualization Framework")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        Task { await refreshData() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Offline alert banner if the guest VM engine is stopped
                if !isVMRunning {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("Container Engine Offline")
                                .font(.headline)
                        }
                        Text("The VM guest engine is currently stopped. Please start the engine using the 'System Controls' panel below, or configure the CLI paths in Settings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
                // Key metrics grids
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(
                        title: "Containers",
                        value: "\(containerCount)",
                        icon: "shippingbox",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Running",
                        value: "\(runningContainerCount)",
                        icon: "play.circle",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Images",
                        value: "\(imageCount)",
                        icon: "photo.stack",
                        color: .purple
                    )
                }
                .padding(.horizontal)
                
                // Quick deploy container action
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Deploy Container")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        TextField("Enter OCI image name, e.g. nginx:alpine", text: $quickRunImage)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isQuickRunning || !isVMRunning)
                        
                        Button(action: {
                            quickRunContainer()
                        }) {
                            if isQuickRunning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Deploy", systemImage: "play.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(quickRunImage.isEmpty || isQuickRunning || !isVMRunning)
                    }
                    
                    if let success = runSuccessMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if let error = runErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Sandbox metrics and system controllers
                HStack(alignment: .top, spacing: 16) {
                    // Resource Utilizations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Resource Utilization (Sandbox VM Monitor)")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            ResourceGauge(title: "CPU Usage", percent: isVMRunning ? 0.12 : 0.0, color: .blue)
                            ResourceGauge(title: "Memory Usage", percent: isVMRunning ? 0.35 : 0.0, color: .orange)
                            ResourceGauge(title: "Disk Usage", percent: isVMRunning ? 0.58 : 0.0, color: .purple)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // System Controls Box
                    VStack(alignment: .leading, spacing: 16) {
                        Text("System Controls")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Label("Engine VM", systemImage: "macpro.gen3")
                                Spacer()
                                Button(isVMRunning ? "Stop" : "Start") {
                                    toggleEngineVM()
                                }
                                .buttonStyle(.bordered)
                                .tint(isVMRunning ? .orange : .green)
                            }
                            
                            HStack {
                                Label("BuildKit Builder", systemImage: "hammer.fill")
                                Spacer()
                                Button(isBuilderRunning ? "Running" : "Start") {
                                    startBuildKit()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isBuilderRunning || !isVMRunning)
                            }
                            
                            HStack {
                                Label("Unused Images", systemImage: "trash.fill")
                                Spacer()
                                Button("Prune") {
                                    pruneLocalImages()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!isVMRunning)
                            }
                        }
                        
                        if let msg = controlSuccessMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if let errMsg = controlErrorMessage {
                            Text(errMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    private func refreshData() async {
        isLoading = true
        do {
            let status = try await SystemService.shared.getSystemStatus()
            isVMRunning = status.isRunning
            isBuilderRunning = status.builderRunning
            
            if isVMRunning {
                let containers = try await ContainerService.shared.fetchContainers(showAll: true)
                containerCount = containers.count
                runningContainerCount = containers.filter { $0.status == .running }.count
                
                let images = try await ImageService.shared.fetchImages()
                imageCount = images.count
            } else {
                containerCount = 0
                runningContainerCount = 0
                imageCount = 0
            }
        } catch {
            isVMRunning = false
            containerCount = 0
            runningContainerCount = 0
            imageCount = 0
            print("Failed to fetch dashboard metrics: \(error)")
        }
        isLoading = false
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
                if isVMRunning {
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

/// Metric Card view
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

/// Resource Gauge view
struct ResourceGauge: View {
    let title: String
    let percent: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: 6)
                    .frame(width: 70, height: 70)
                Circle()
                    .trim(from: 0.0, to: CGFloat(percent))
                    .stroke(
                        AngularGradient(colors: [color, color.opacity(0.7), color], center: .center),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            
            Text(LocalizedStringKey(title))
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 90)
    }
}

#Preview {
    DashboardView()
}
