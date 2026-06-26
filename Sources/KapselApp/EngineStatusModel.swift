import SwiftUI
import KapselKit

/// Shared engine detection state for the entire app
@MainActor
@Observable
final class EngineStatusModel {
    static let shared = EngineStatusModel()

    private(set) var installStatus: EngineInstallStatus = .checking
    private(set) var isHomebrewCaskAvailable: Bool = false

    var isChecking: Bool {
        installStatus == .checking
    }

    var isCLIInstalled: Bool {
        if case .installed = installStatus { return true }
        return false
    }

    var installedCLIPath: String? {
        if case .installed(let path) = installStatus { return path }
        return nil
    }

    private init() {}

    func refresh() async {
        installStatus = .checking

        let detection = await Task.detached {
            await EngineInstallService.shared.detectEngine()
        }.value

        installStatus = detection

        if case .notInstalled = detection {
            isHomebrewCaskAvailable = await EngineInstallService.shared.isContainerCaskAvailable()
        } else {
            isHomebrewCaskAvailable = false
        }
    }
}

extension EngineStatusModel {
    /// Convenience for views that only need a bool after detection completes
    var shouldShowInstallUI: Bool {
        installStatus == .notInstalled
    }
}
