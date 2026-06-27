import SwiftUI
import KapselKit

/// Keeps the container list alive across view rebuilds so switching tabs
/// shows cached data instantly while refreshing silently in the background.
@MainActor
@Observable
final class ContainersStore {
    private(set) var containers: [Container] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var inFlight = false

    func load(showAll: Bool) async {
        if inFlight { return }
        inFlight = true
        defer { inFlight = false }
        do {
            containers = try await ContainerService.shared.fetchContainers(showAll: showAll)
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Keeps dashboard metrics alive across rebuilds.
@MainActor
@Observable
final class DashboardStore {
    private(set) var containerCount = 0
    private(set) var runningContainerCount = 0
    private(set) var imageCount = 0
    private(set) var isVMRunning = false
    private(set) var isBuilderRunning = false
    private(set) var kernelInstalled = false
    private(set) var kernelVersion: String?
    private(set) var hasLoaded = false

    private var inFlight = false

    func refresh(isCLIInstalled: Bool) async {
        if inFlight { return }
        inFlight = true
        defer { inFlight = false }

        guard isCLIInstalled else {
            reset()
            hasLoaded = true
            return
        }

        do {
            let status = try await SystemService.shared.getSystemStatus()
            isVMRunning = status.isRunning
            isBuilderRunning = status.builderRunning
            hasLoaded = true

            if let kernel = try? await KernelService.shared.getConfiguration() {
                kernelInstalled = kernel.isInstalled
                kernelVersion = kernel.versionLabel
            }

            guard isVMRunning else {
                containerCount = 0
                runningContainerCount = 0
                imageCount = 0
                return
            }

            do {
                let containers = try await ContainerService.shared.fetchContainers(showAll: true)
                containerCount = containers.count
                runningContainerCount = containers.filter { $0.status == .running }.count
                imageCount = try await ImageService.shared.fetchImages().count
            } catch {
                print("Failed to fetch dashboard metrics: \(error)")
            }
        } catch {
            reset()
            hasLoaded = true
            print("Failed to fetch system status: \(error)")
        }
    }

    private func reset() {
        isVMRunning = false
        isBuilderRunning = false
        kernelInstalled = false
        kernelVersion = nil
        containerCount = 0
        runningContainerCount = 0
        imageCount = 0
    }
}

/// Keeps the image list alive across rebuilds.
@MainActor
@Observable
final class ImagesStore {
    private(set) var images: [ContainerImage] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var inFlight = false

    func load() async {
        if inFlight { return }
        inFlight = true
        defer { inFlight = false }
        do {
            images = try await ImageService.shared.fetchImages()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Keeps services/VM state alive across rebuilds.
@MainActor
@Observable
final class SystemStore {
    private(set) var engineRunning = false
    private(set) var builderRunning = false
    private(set) var kernelInstalled = false
    private(set) var kernelVersion: String?
    private(set) var dnsDomain = ""
    private(set) var systemLogs = ""
    private(set) var systemProperties = ""
    private(set) var registryStatus = ""
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var inFlight = false

    func refresh() async {
        if inFlight { return }
        inFlight = true
        defer { inFlight = false }

        do {
            let status = try await SystemService.shared.getSystemStatus()
            engineRunning = status.isRunning
            dnsDomain = status.dnsDomain ?? ""
            builderRunning = status.builderRunning
            hasLoaded = true

            if let kernel = try? await KernelService.shared.getConfiguration() {
                kernelInstalled = kernel.isInstalled
                kernelVersion = kernel.versionLabel
            }

            if engineRunning {
                systemProperties = (try? await SystemService.shared.getProperties())
                    ?? String(localized: "Engine is offline. VM properties are not loaded.")
                registryStatus = (try? await SystemService.shared.listRegistries())
                    ?? String(localized: "Engine is offline. Private registries not loaded.")
                systemLogs = (try? await SystemService.shared.getSystemLogs())
                    ?? String(localized: "Engine is offline. System logs are empty.")
            } else {
                systemProperties = String(localized: "Engine is offline. VM properties are not loaded.")
                registryStatus = String(localized: "Engine is offline. Private registries not loaded.")
                systemLogs = String(localized: "Engine is offline. System logs are empty.")
            }
            errorMessage = nil
        } catch {
            engineRunning = false
            builderRunning = false
            kernelInstalled = false
            kernelVersion = nil
            systemProperties = String(localized: "Engine is offline. VM properties are not loaded.")
            registryStatus = String(localized: "Engine is offline. Private registries not loaded.")
            systemLogs = String(localized: "Engine is offline. System logs are empty.")
            errorMessage = String(localized: "Failed to load system status: \(error.localizedDescription)")
            hasLoaded = true
        }
    }
}

/// Shared engine runtime state with a resident poller. Used by both the
/// sidebar footer and the menu bar item so they always agree and keep
/// updating even when the main window is closed.
@MainActor
@Observable
final class EngineRuntimeModel {
    private(set) var isRunning = false
    private(set) var isBuilderRunning = false
    var isToggling = false

    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    /// Starts a resident 5s polling loop. Idempotent.
    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func refresh() async {
        guard EngineStatusModel.shared.isCLIInstalled else {
            isRunning = false
            isBuilderRunning = false
            return
        }
        do {
            let status = try await SystemService.shared.getSystemStatus()
            isRunning = status.isRunning
            isBuilderRunning = status.builderRunning
        } catch {
            isRunning = false
            isBuilderRunning = false
        }
    }

    func toggle() async {
        guard EngineStatusModel.shared.isCLIInstalled, !isToggling else { return }
        isToggling = true
        do {
            if isRunning {
                try await SystemService.shared.stopSystem()
            } else {
                try await SystemService.shared.startSystem()
            }
            await refresh()
        } catch {
            print("Failed to toggle engine status: \(error)")
        }
        isToggling = false
    }
}
