import Foundation

/// Represents a container image data model, aligning with `container image ls --verbose --format json`
public struct ContainerImage: Identifiable, Codable, Equatable, Sendable {
    /// Using the image digest as the unique identifier
    public var id: String { digest }
    
    /// Repository name (e.g. "library/nginx" or "ubuntu")
    public let repository: String
    
    /// Image tag (e.g. "latest")
    public let tag: String
    
    /// Unique digest hash (e.g. "sha256:...")
    public let digest: String
    
    /// Human-readable image size (e.g. "42.8 MB")
    public let size: String?
    
    /// Target operating system (e.g. "linux")
    public let os: String?
    
    /// Target CPU architecture (e.g. "arm64")
    public let arch: String?
    
    /// CPU architecture variant
    public let variant: String?
    
    /// Manifest digest (e.g. "sha256:...")
    public let manifestDigest: String?
    
    /// Creation or pull timestamp
    public let createdAt: String?
    
    /// Returns the full image name (e.g. "ubuntu:latest")
    public var fullName: String {
        "\(repository):\(tag)"
    }
    
    /// Initializer
    public init(
        repository: String,
        tag: String,
        digest: String,
        size: String? = nil,
        os: String? = nil,
        arch: String? = nil,
        variant: String? = nil,
        manifestDigest: String? = nil,
        createdAt: String? = nil
    ) {
        self.repository = repository
        self.tag = tag
        self.digest = digest
        self.size = size
        self.os = os
        self.arch = arch
        self.variant = variant
        self.manifestDigest = manifestDigest
        self.createdAt = createdAt
    }
}
