import Foundation

/// Represents the engine running status and network configuration
public struct SystemStatus: Codable, Sendable, Equatable {
    /// Indicates whether the container engine is currently running
    public let isRunning: Bool
    
    /// The currently configured DNS domain
    public let dnsDomain: String?
    
    /// The currently configured network subnet
    public let networkSubnet: String?
    
    /// Indicates whether the BuildKit builder VM is running
    public let builderRunning: Bool
    
    /// Initializer
    public init(isRunning: Bool, dnsDomain: String? = nil, networkSubnet: String? = nil, builderRunning: Bool = false) {
        self.isRunning = isRunning
        self.dnsDomain = dnsDomain
        self.networkSubnet = networkSubnet
        self.builderRunning = builderRunning
    }
}
