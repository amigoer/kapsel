import Foundation

/// Service managing virtual machines, system configurations, BuildKit builders, and registry authorizations
public final class SystemService: Sendable {
    
    /// Shared singleton instance of SystemService
    public static let shared = SystemService()
    
    private let cli = CLIService.shared
    
    public init() {}
    
    // MARK: - System VM Management
    
    /// Starts the underlying virtual machine and guest engine
    public func startSystem() async throws {
        _ = try await cli.run(arguments: ["system", "start"])
    }
    
    /// Gracefully stops the container engine virtual machine
    public func stopSystem() async throws {
        _ = try await cli.run(arguments: ["system", "stop"])
    }
    
    /// Inspects the overall execution status of the system VM
    /// - Returns: Current system status configuration model
    public func getSystemStatus() async throws -> SystemStatus {
        return try await cli.runAndDecodeJSON(arguments: ["system", "status"], type: SystemStatus.self)
    }
    
    /// Fetches diagnostic system kernel logs
    /// - Returns: Logs string content
    public func getSystemLogs() async throws -> String {
        return try await cli.run(arguments: ["system", "logs"])
    }
    
    // MARK: - DNS Routing
    
    /// Binds a specific DNS mapping inside the virtual bridge network
    /// - Parameter domain: Local resolution domain
    public func createDNSDomain(domain: String) async throws {
        _ = try await cli.run(arguments: ["system", "dns", "add", domain])
    }
    
    /// Removes a specific DNS configuration domain mapping
    /// - Parameter domain: Resolution domain to clear
    public func deleteDNSDomain(domain: String) async throws {
        _ = try await cli.run(arguments: ["system", "dns", "remove", domain])
    }
    
    /// Configurations default DNS responder domains
    /// - Parameter domain: Target gateway domain name
    public func setDefaultDNS(domain: String) async throws {
        _ = try await cli.run(arguments: ["system", "dns", "default", domain])
    }
    
    // MARK: - Configuration Properties
    
    /// Lists all runtime system VM configurations (properties)
    /// - Returns: Formatted parameters list string
    public func getProperties() async throws -> String {
        return try await cli.run(arguments: ["system", "property", "list"])
    }
    
    /// Configures a specific runtime property
    /// - Parameters:
    ///   - id: Key name of the property
    ///   - value: Configured string value
    public func setProperty(id: String, value: String) async throws {
        _ = try await cli.run(arguments: ["system", "property", "set", id, value])
    }
    
    /// Restores a specific runtime system VM property to its default state
    /// - Parameter id: Target key identifier
    public func clearProperty(id: String) async throws {
        _ = try await cli.run(arguments: ["system", "property", "clear", id])
    }
    
    // MARK: - Builder (BuildKit)
    
    /// Spawns and starts the BuildKit virtual compile guest VM
    public func startBuilder() async throws {
        _ = try await cli.run(arguments: ["builder", "start"])
    }
    
    /// Inspects BuildKit service status
    /// - Returns: Diagnostics description string
    public func getBuilderStatus() async throws -> String {
        return try await cli.run(arguments: ["builder", "status"])
    }
    
    // MARK: - Registries Authorization
    
    /// Lists all registry hosts currently authorized
    /// - Returns: Accounts credentials listing
    public func listRegistries() async throws -> String {
        return try await cli.run(arguments: ["registry", "list"])
    }
    
    /// Configures login credentials for private OCI registries
    /// - Parameters:
    ///   - url: Registry hostname (e.g. docker.io)
    ///   - username: Username credential
    ///   - password: Password credential
    public func loginRegistry(url: String, username: String, password: String) async throws {
        _ = try await cli.run(arguments: ["registry", "login", url, "-u", username, "-p", password])
    }
    
    // MARK: - CLI Diagnostics
    
    /// Fetches the local CLI release version string
    public func getCLIVersion() async throws -> String {
        return try await cli.run(arguments: ["--version"])
    }
}
