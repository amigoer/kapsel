import SwiftUI
import KapselKit

/// Middle column: native container list (OrbStack-style)
struct ContainerListColumn: View {
    @Binding var selection: String?
    @Environment(ContainersStore.self) private var store
    @State private var searchText = ""
    @State private var showAll = false
    @State private var isRefreshing = false
    @State private var isShowingCreateSheet = false
    @State private var timer: Timer?

    private var filteredContainers: [Container] {
        store.containers.filter { container in
            searchText.isEmpty
                || container.name.localizedCaseInsensitiveContains(searchText)
                || container.image.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var runningCount: Int {
        store.containers.filter { $0.status == .running }.count
    }

    var body: some View {
        Group {
            if filteredContainers.isEmpty {
                ContentUnavailableView {
                    Label("No Containers Found", systemImage: "shippingbox")
                } description: {
                    Text(searchText.isEmpty
                         ? LocalizedStringKey("Click 'Deploy Container' at the top right to create your first container instance.")
                         : LocalizedStringKey("Try changing search terms"))
                } actions: {
                    Button("Deploy Container") {
                        isShowingCreateSheet = true
                    }
                }
            } else {
                List(filteredContainers, selection: $selection) { container in
                    ContainerListRow(container: container)
                        .tag(container.name)
                        .contextMenu {
                            containerContextMenu(for: container)
                        }
                }
            }
        }
        .overlay {
            if !store.hasLoaded {
                ProgressView("Loading container list...")
            }
        }
        .disabled(!store.hasLoaded)
        .navigationTitle("Containers")
        .navigationSubtitle("\(runningCount) running")
        .restoreSidebarFocusWhenLoaded(store.hasLoaded)
        .searchable(text: $searchText, prompt: Text("Search by name or image..."))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingCreateSheet = true
                } label: {
                    Label("Deploy Container", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Toggle("Show All Containers", isOn: $showAll)
                    .toggleStyle(.checkbox)
                    .onChange(of: showAll) { _, _ in
                        Task { await loadContainers() }
                    }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadContainers() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .alert("Operation Failed", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $isShowingCreateSheet) {
            ContainerCreateView(onDismiss: {
                isShowingCreateSheet = false
                Task { await loadContainers() }
            })
        }
        .onAppear {
            Task { await loadContainers() }
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    @ViewBuilder
    private func containerContextMenu(for container: Container) -> some View {
        Button("Start") { startContainer(container) }
            .disabled(container.status == .running)
        Button("Stop") { stopContainer(container) }
            .disabled(container.status != .running)
        Button("Force Kill (Kill)") { killContainer(container) }
            .disabled(container.status != .running)
        Divider()
        Button("Delete Container") { deleteContainer(container) }
            .disabled(container.status == .running)
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                await store.load(showAll: showAll)
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func loadContainers() async {
        isRefreshing = true
        await store.load(showAll: showAll)
        if let selection, !store.containers.contains(where: { $0.name == selection }) {
            self.selection = store.containers.first?.name
        } else if selection == nil {
            selection = store.containers.first?.name
        }
        isRefreshing = false
    }

    private func startContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.startContainer(name: container.name)
                await loadContainers()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private func stopContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.stopContainer(name: container.name)
                await loadContainers()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private func killContainer(_ container: Container) {
        Task {
            do {
                try await ContainerService.shared.killContainer(name: container.name)
                await loadContainers()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteContainer(_ container: Container) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Confirm Deletion")
        alert.informativeText = String(localized: "Are you sure you want to delete container: \(container.name)? This action cannot be undone.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                do {
                    try await ContainerService.shared.deleteContainer(name: container.name)
                    await loadContainers()
                } catch {
                    store.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct ContainerListRow: View {
    let container: Container

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(container.name)
                    .font(.body)
                Spacer()
                StatusBadge(status: container.status)
            }
            Text(container.image)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let address = container.address, !address.isEmpty {
                Text(address)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
