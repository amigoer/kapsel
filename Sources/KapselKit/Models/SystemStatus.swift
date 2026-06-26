import Foundation

/// Raw JSON payload returned by `container system status --format json`
struct SystemStatusResponse: Decodable, Sendable, Equatable {
    let status: String
    let appRoot: String
    let installRoot: String
    let logRoot: String?
    let apiServerVersion: String
    let apiServerCommit: String
    let apiServerBuild: String
    let apiServerAppName: String

    var isRunning: Bool {
        status == "running"
    }
}

/// Aggregate system status used by the GUI
public struct SystemStatus: Sendable, Equatable {
    public let status: String
    public let appRoot: String
    public let installRoot: String
    public let logRoot: String?
    public let apiServerVersion: String
    public let apiServerCommit: String
    public let apiServerBuild: String
    public let apiServerAppName: String

    /// Whether the container API server is running
    public let isRunning: Bool

    /// Whether the BuildKit builder container is running
    public let builderRunning: Bool

    /// Default DNS domain, if configured
    public let dnsDomain: String?

    init(
        response: SystemStatusResponse,
        builderRunning: Bool = false,
        dnsDomain: String? = nil
    ) {
        status = response.status
        appRoot = response.appRoot
        installRoot = response.installRoot
        logRoot = response.logRoot
        apiServerVersion = response.apiServerVersion
        apiServerCommit = response.apiServerCommit
        apiServerBuild = response.apiServerBuild
        apiServerAppName = response.apiServerAppName
        isRunning = response.isRunning
        self.builderRunning = builderRunning
        self.dnsDomain = dnsDomain
    }

    /// Convenience initializer for tests and previews
    public init(
        isRunning: Bool,
        dnsDomain: String? = nil,
        networkSubnet: String? = nil,
        builderRunning: Bool = false
    ) {
        status = isRunning ? "running" : "not running"
        appRoot = ""
        installRoot = ""
        logRoot = nil
        apiServerVersion = ""
        apiServerCommit = ""
        apiServerBuild = ""
        apiServerAppName = ""
        self.isRunning = isRunning
        self.builderRunning = builderRunning
        self.dnsDomain = dnsDomain
        _ = networkSubnet
    }
}

/// Builder entry returned by `container builder status --format json`
struct BuilderStatusEntry: Decodable, Sendable {
    let status: String

    var isRunning: Bool {
        status.lowercased() == "running"
    }
}

/// DNS entry returned by `container system dns list --format json`
struct SystemDNSEntry: Decodable, Sendable {
    let domain: String?
    let name: String?

    var resolvedDomain: String? {
        if let domain, !domain.isEmpty { return domain }
        if let name, !name.isEmpty { return name }
        return nil
    }
}

extension SystemStatusResponse {
    static func decode(from rawOutput: String) throws -> SystemStatusResponse {
        guard let data = rawOutput.data(using: .utf8) else {
            throw CLIError.invalidOutput
        }

        do {
            return try JSONDecoder().decode(SystemStatusResponse.self, from: data)
        } catch {
            throw CLIError.decodingFailed(details: "\(error.localizedDescription). Raw output: \(rawOutput)")
        }
    }
}
