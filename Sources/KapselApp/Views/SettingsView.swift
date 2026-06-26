import SwiftUI
import KapselKit

///首选项设置视图，支持配置 CLI 路径并查看系统关于信息
struct SettingsView: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(EngineStatusModel.self) private var engineStatus
    @State private var cliPath: String = ""
    @State private var cliVersion: String = "Loading..."
    @State private var showSaveFeedback: Bool = false
    
    var body: some View {
        Form {
            Section("General") {
                Picker("App Language", selection: Bindable(languageManager).selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        languageLabel(for: language).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Text("Language changes take effect immediately.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if engineStatus.isChecking {
                Section("Engine Setup") {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Detecting container engine...")
                            .foregroundColor(.secondary)
                    }
                }
            } else if engineStatus.shouldShowInstallUI {
                Section("Engine Setup") {
                    EngineSetupBanner {
                        Task {
                            await engineStatus.refresh()
                            syncCLIPathFromDetection()
                            fetchCLIVersion()
                        }
                    }
                }
            }

            Section("Engine Executable Configuration") {
                if engineStatus.isCLIInstalled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Engine Status:")
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(LocalizedStringKey("Online"))
                                    .foregroundColor(.green)
                            }
                        }

                        HStack(spacing: 6) {
                            Text("Engine Version:")
                            Text(LocalizedStringKey(cliVersion))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.footnote)
                    .padding(.vertical, 4)
                }

                DisclosureGroup("Advanced: Configure CLI Path Manually") {
                    HStack(spacing: 8) {
                        TextField("container CLI absolute path", text: $cliPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            selectCLIPath()
                        }
                    }

                    HStack {
                        Button(action: saveSettings) {
                            Text("Save & Apply")
                        }
                        .buttonStyle(.borderedProminent)

                        if showSaveFeedback {
                            Text("✓ Settings successfully saved and applied")
                                .foregroundColor(.green)
                                .font(.footnote)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 6)
                }
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
            syncCLIPathFromDetection()
            fetchCLIVersion()
        }
        .onChange(of: engineStatus.installStatus) { _, _ in
            syncCLIPathFromDetection()
            fetchCLIVersion()
        }
    }
    
    private func languageLabel(for language: AppLanguage) -> some View {
        switch language {
        case .system:
            Text("System Default")
        case .english:
            Text("English")
        case .simplifiedChinese:
            Text("简体中文")
        }
    }
    
    private func syncCLIPathFromDetection() {
        if let path = engineStatus.installedCLIPath {
            cliPath = path
        } else {
            cliPath = CLIService.shared.cliPath
        }
    }
    
    private func fetchCLIVersion() {
        guard engineStatus.isCLIInstalled else {
            cliVersion = languageManager.localized("No engine version detected")
            return
        }

        Task {
            do {
                let version = try await SystemService.shared.getCLIVersion()
                cliVersion = version
            } catch {
                cliVersion = languageManager.localized("No engine version detected")
            }
        }
    }
    
    private func saveSettings() {
        CLIService.shared.cliPath = cliPath
        
        withAnimation {
            showSaveFeedback = true
        }
        
        Task {
            await engineStatus.refresh()
            fetchCLIVersion()
        }
        
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
        panel.title = languageManager.localized("Locate container CLI tool")
        
        if panel.runModal() == .OK {
            cliPath = panel.url?.path ?? ""
            saveSettings()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppLanguageManager.shared)
        .environment(EngineStatusModel.shared)
}
