import Foundation

/// Service managing the lifecycle of container images by wrapping image CLI commands
public final class ImageService: Sendable {
    
    /// Shared singleton instance of ImageService
    public static let shared = ImageService()
    
    private let cli = CLIService.shared
    
    public init() {}
    
    /// Fetches the list of locally pulled images
    /// - Returns: Array of local container images
    public func fetchImages() async throws -> [ContainerImage] {
        return try await cli.runAndDecodeJSON(arguments: ["image", "list", "--verbose"], type: [ContainerImage].self)
    }
    
    /// Pulls a remote image from an OCI-compliant registry
    /// - Parameter name: Full image name (e.g. "docker.io/library/ubuntu:latest")
    public func pullImage(name: String) async throws {
        _ = try await cli.run(arguments: ["image", "pull", name])
    }
    
    /// Deletes a specific image from the local storage
    /// - Parameter digest: The digest or repository:tag identifier of the target image
    public func deleteImage(digest: String) async throws {
        _ = try await cli.run(arguments: ["image", "rm", digest])
    }
    
    /// Builds an image locally based on a build context and configurations
    /// - Parameters:
    ///   - tag: Name and optionally a tag in the 'name:tag' format
    ///   - buildContextPath: Local path containing the Dockerfile and source files
    ///   - arch: Specify target architecture, e.g. "arm64"
    ///   - platform: Specify target operating system and architecture, e.g. "linux/arm64"
    ///   - buildArgs: Compilation arguments passed to the build process
    ///   - dockerfile: Custom path to the Dockerfile
    public func buildImage(
        tag: String,
        buildContextPath: String,
        arch: String? = nil,
        platform: String? = nil,
        buildArgs: [String]? = nil,
        dockerfile: String? = nil
    ) async throws {
        var args = ["image", "build", "-t", tag]
        if let arch = arch, !arch.isEmpty {
            args.append(contentsOf: ["--arch", arch])
        }
        if let platform = platform, !platform.isEmpty {
            args.append(contentsOf: ["--platform", platform])
        }
        if let buildArgs = buildArgs {
            for arg in buildArgs where !arg.isEmpty {
                args.append(contentsOf: ["--build-arg", arg])
            }
        }
        if let dockerfile = dockerfile, !dockerfile.isEmpty {
            args.append(contentsOf: ["--file", dockerfile])
        }
        args.append(buildContextPath)
        
        _ = try await cli.run(arguments: args)
    }
    
    /// Pushes a local image to a remote registry
    /// - Parameter name: Full name of the image to push
    public func pushImage(name: String) async throws {
        _ = try await cli.run(arguments: ["image", "push", name])
    }
    
    /// Tags a source image with a target repository name and tag
    /// - Parameters:
    ///   - source: Name or ID of the source image
    ///   - target: New target tag name
    public func tagImage(source: String, target: String) async throws {
        _ = try await cli.run(arguments: ["image", "tag", source, target])
    }
    
    /// Cleans up unused local container images
    public func pruneImages() async throws {
        _ = try await cli.run(arguments: ["image", "prune", "-f"])
    }
    
    /// Inspects the detailed JSON configurations of an image
    /// - Parameter name: Repository name, tag, or digest hash
    /// - Returns: JSON formatted metadata of the image
    public func inspectImage(name: String) async throws -> String {
        return try await cli.run(arguments: ["image", "inspect", name])
    }
}
