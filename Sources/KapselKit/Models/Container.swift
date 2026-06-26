import Foundation

/// Represents a container instance data model, aligning with the output of `container ls --format json`
public struct Container: Identifiable, Codable, Equatable, Sendable {
    /// Unique identifier required by the Identifiable protocol, returns the containerID
    public var id: String { containerID }
    
    /// The unique container ID mapped to the "id" field in JSON
    public let containerID: String
    
    /// The name of the container
    public let name: String
    
    /// The image name used by the container (e.g. "library/ubuntu:latest")
    public let image: String
    
    /// The current execution status of the container
    public let status: Status
    
    /// The network address (corresponds to the ADDR field in CLI)
    public let address: String?
    
    /// The creation timestamp (CLI may return non-standard format, represented as String)
    public let createdAt: String?
    
    /// The operating system type (defaults to "linux")
    public let os: String
    
    /// The CPU architecture (defaults to "arm64")
    public let arch: String
    
    /// Allocated CPU cores count
    public let cpus: Int?
    
    /// Allocated memory limit (e.g. "512M", "2G")
    public let memory: String?
    
    private enum CodingKeys: String, CodingKey {
        case containerID = "id"
        case name
        case image
        case status
        case address
        case createdAt
        case os
        case arch
        case cpus
        case memory
    }
    
    /// Container execution status enum
    public enum Status: String, Codable, Sendable, CaseIterable {
        case running = "running"
        case stopped = "stopped"
        case paused = "paused"
        case created = "created"
        case unknown = "unknown"
        
        /// Friendly English display name
        public var displayName: String {
            switch self {
            case .running: return "Running"
            case .stopped: return "Stopped"
            case .paused: return "Paused"
            case .created: return "Created"
            case .unknown: return "Unknown"
            }
        }
    }
    
    /// Initializer
    public init(
        containerID: String,
        name: String,
        image: String,
        status: Status,
        address: String? = nil,
        createdAt: String? = nil,
        os: String = "linux",
        arch: String = "arm64",
        cpus: Int? = nil,
        memory: String? = nil
    ) {
        self.containerID = containerID
        self.name = name
        self.image = image
        self.status = status
        self.address = address
        self.createdAt = createdAt
        self.os = os
        self.arch = arch
        self.cpus = cpus
        self.memory = memory
    }
}
