import SwiftUI
import KapselKit

///首选项设置视图，支持配置 CLI 路径并查看系统关于信息
struct SettingsView: View {
    @State private var cliPath: String = ""
    @State private var engineOnline: Bool = false
    @State private var cliVersion: String = "Loading..."
    @State private var showSaveFeedback: Bool = false
    
    var body: some View {
        Form {
            Section("Engine Executable Configuration") {
                HStack(spacing: 8) {
                    TextField("container CLI absolute path", text: $cliPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        selectCLIPath()
                    }
                }
                
                // Engine status and version details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Engine Status:")
                        HStack(spacing: 4) {
                            Circle()
                                .fill(engineOnline ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(engineOnline ? "Online" : "Offline")
                                .foregroundColor(engineOnline ? .green : .red)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text("Engine Version:")
                        Text(cliVersion)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.footnote)
                .padding(.vertical, 4)
                
                HStack {
                    Button(action: saveSettings) {
                        Text("Save & Apply")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/apple/container/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Get container engine", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    
                    if showSaveFeedback {
                        Text("✓ Settings successfully saved and applied")
                            .foregroundColor(.green)
                            .font(.footnote)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 6)
            }
            
            Section("About Kapsel") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Kapsel Desktop Client")
                            .font(.headline)
                        Text("v1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Kapsel is a native macOS graphical client built to manage the apple/container engine. Harnessing Apple's virtualization framework, it provides developer-focused, sandbox-isolated container environments directly on macOS.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .lineSpacing(4)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/apple/container") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("apple/container Repository", systemImage: "safari")
                        }
                        .buttonStyle(.link)
                        
                        Button(action: {
                            if let url = URL(string: "https://github.com/apple/container/releases") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Download Release Binaries", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSettings()
            autoDetectCLIPath()
            fetchCLIVersion()
        }
    }
    
    private func loadSettings() {
        cliPath = CLIService.shared.cliPath
        checkEngineStatus()
    }
    
    private func checkEngineStatus() {
        let exists = FileManager.default.fileExists(atPath: cliPath)
        engineOnline = exists
    }
    
    private func autoDetectCLIPath() {
        let paths = [
            "/opt/homebrew/bin/container",
            "/usr/local/bin/container",
            "/usr/bin/container"
        ]
        
        if cliPath.isEmpty || !FileManager.default.fileExists(atPath: cliPath) {
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    cliPath = path
                    saveSettings()
                    break
                }
            }
        }
    }
    
    private func fetchCLIVersion() {
        Task {
            do {
                let version = try await SystemService.shared.getCLIVersion()
                cliVersion = version
            } catch {
                cliVersion = "No engine version detected"
            }
        }
    }
    
    private func saveSettings() {
        CLIService.shared.cliPath = cliPath
        checkEngineStatus()
        
        withAnimation {
            showSaveFeedback = true
        }
        
        fetchCLIVersion()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveFeedback = false
            }
        }
    }
    
    private func selectCLIPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Locate container CLI tool"
        
        if panel.runModal() == .OK {
            cliPath = panel.url?.path ?? ""
            saveSettings()
        }
    }
}

#Preview {
    SettingsView()
}
