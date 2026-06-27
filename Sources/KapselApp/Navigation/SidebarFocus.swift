import SwiftUI

/// Restores keyboard/focus to the sidebar after detail content finishes loading.
/// On macOS, sidebar selection appears gray when the detail column steals focus.
private struct RestoreSidebarFocusKey: EnvironmentKey {
    static let defaultValue: @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var restoreSidebarFocus: @Sendable () -> Void {
        get { self[RestoreSidebarFocusKey.self] }
        set { self[RestoreSidebarFocusKey.self] = newValue }
    }
}

/// Call after async detail loads so the sidebar keeps the accent selection appearance.
struct SidebarFocusRestorer: ViewModifier {
    @Environment(\.restoreSidebarFocus) private var restoreSidebarFocus
    let trigger: Bool

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, loaded in
            if loaded {
                restoreSidebarFocus()
            }
        }
    }
}

extension View {
    func restoreSidebarFocusWhenLoaded(_ loaded: Bool) -> some View {
        modifier(SidebarFocusRestorer(trigger: loaded))
    }
}
