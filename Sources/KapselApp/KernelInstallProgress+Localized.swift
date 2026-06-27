import SwiftUI
import KapselKit

extension KernelInstallProgress {
    /// Localized detail text for UI display.
    var localizedDetail: String {
        switch stage {
        case .preparing:
            return String(localized: "Reading kernel configuration…")
        case .downloading:
            if let fractionCompleted {
                let percent = Int((fractionCompleted * 100).rounded())
                return String(format: String(localized: "Downloading kernel archive… %lld%%"), percent)
            }
            return String(localized: "Downloading kernel archive…")
        case .installing:
            if detail.localizedCaseInsensitiveContains("extract") {
                return String(localized: "Extracting and installing kernel…")
            }
            return String(localized: "Extracting and installing kernel…")
        case .removing:
            if detail.localizedCaseInsensitiveContains("BuildKit") {
                return String(localized: "Stopping BuildKit builder…")
            }
            return String(localized: "Removing kernel files…")
        }
    }

    var localizedForDisplay: KernelInstallProgress {
        KernelInstallProgress(stage: stage, fractionCompleted: fractionCompleted, detail: localizedDetail)
    }
}
