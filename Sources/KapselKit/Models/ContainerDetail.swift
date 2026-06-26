import Foundation

/// Detailed configuration and execution details of a container instance, corresponding to `container inspect` JSON output
public struct ContainerDetail: Codable, Sendable, Equatable {
    /// Unique container ID
    public let id: String
    
    /// Container name
    public let name: String
    
    /// Image used by the container
    public let image: String
    
    /// Current execution state (e.g. "running", "stopped")
    public let status: String
    
    /// Network IP address assigned to the container
    public let address: String?
    
    /// Exposed port mappings
    public let ports: [PortMapping]?
    
    /// Bound storage volumes
    public let volumes: [VolumeMount]?
    
    /// List of environment variables (format "KEY=VALUE")
    public let env: [String]?
    
    /// Entrypoint overrides
    public let entrypoint: String?
    
    /// Command overrides
    public let command: String?
    
    /// Allocated CPU cores
    public let cpus: Int?
    
    /// Allocated memory limit
    public let memory: String?
    
    /// Inside hostname
    public let hostname: String?
    
    /// Target operating system
    public let os: String?
    
    /// Target CPU architecture
    public let arch: String?
    
    /// Port mapping structure
    public struct PortMapping: Codable, Sendable, Identifiable, Equatable {
        /// Unique identifier combining hostPort and containerPort
        public var id: String { "\(hostPort)-\(containerPort)" }
        
        /// Port exposed on the host machine
        public let hostPort: Int
        
        /// Port inside the container
        public let containerPort: Int
        
        /// Network protocol type (tcp / udp)
        public let protocolType: String?
        
        private enum CodingKeys: String, CodingKey {
            case hostPort
            case containerPort
            case protocolType = "protocol"
        }
        
        public init(hostPort: Int, containerPort: Int, protocolType: String? = "tcp") {
            self.hostPort = hostPort
            self.containerPort = containerPort
            self.protocolType = protocolType
        }
    }
    
    /// Storage volume mount structure
    public struct VolumeMount: Codable, Sendable, Identifiable, Equatable {
        /// Unique identifier combining hostPath and containerPath
        public var id: String { "\(hostPath)-\(containerPath)" }
        
        /// Path on the host machine
        public let hostPath: String
        
        /// Path inside the container
        public let containerPath: String
        
        /// Read-only restriction
        public let readOnly: Bool
        
        public init(hostPath: String, containerPath: String, readOnly: Bool = false) {
            self.hostPath = hostPath
            self.containerPath = containerPath
            self.readOnly = readOnly
        }
    }
    
    public init(
        id: String,
        name: String,
        image: String,
        status: String,
        address: String? = nil,
        ports: [PortMapping]? = nil,
        volumes: [VolumeMount]? = nil,
        env: [String]? = nil,
        entrypoint: String? = nil,
        command: String? = nil,
        cpus: Int? = nil,
        memory: String? = nil,
        hostname: String? = nil,
        os: String? = "linux",
        arch: String? = "arm64"
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.address = address
        self.ports = ports
        self.volumes = volumes
        self.env = env
        self.entrypoint = entrypoint
        self.command = command
        self.cpus = cpus
        self.memory = memory
        self.hostname = hostname
        self.os = os
        self.arch = arch
    }
}
