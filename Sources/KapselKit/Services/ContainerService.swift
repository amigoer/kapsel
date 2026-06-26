import Foundation

/// Service managing the container lifecycle by wrapping container CLI commands
public final class ContainerService: Sendable {
    
    /// Shared singleton instance of ContainerService
    public static let shared = ContainerService()
    
    private let cli = CLIService.shared
    
    public init() {}
    
    /// Fetches the list of containers
    /// - Parameter showAll: Whether to include stopped containers
    /// - Returns: Array of containers
    public func fetchContainers(showAll: Bool = false) async throws -> [Container] {
        var args = ["ls"]
        if showAll {
            args.append("--all")
        }
        return try await cli.runAndDecodeJSON(arguments: args, type: [Container].self)
    }
    
    /// Starts a stopped container
    /// - Parameter name: Container name or ID
    public func startContainer(name: String) async throws {
        _ = try await cli.run(arguments: ["start", name])
    }
    
    /// Stops a running container gracefully
    /// - Parameter name: Container name or ID
    public func stopContainer(name: String) async throws {
        _ = try await cli.run(arguments: ["stop", name])
    }
    
    /// Kills a running container forcibly
    /// - Parameter name: Container name or ID
    public func killContainer(name: String) async throws {
        _ = try await cli.run(arguments: ["kill", name])
    }
    
    /// Deletes a stopped container
    /// - Parameter name: Container name or ID
    public func deleteContainer(name: String) async throws {
        _ = try await cli.run(arguments: ["rm", name])
    }
    
    /// Fetches output logs of a container
    /// - Parameter name: Container name or ID
    /// - Returns: Log output string
    public func getLogs(name: String) async throws -> String {
        return try await cli.run(arguments: ["logs", name])
    }
    
    /// Executes a command inside a running container
    /// - Parameters:
    ///   - name: Container name or ID
    ///   - command: Command string to execute (e.g. "ls -la")
    /// - Returns: Standard output of the command execution
    public func execCommand(name: String, command: String) async throws -> String {
        return try await cli.run(arguments: ["exec", name, command])
    }
    
    /// Inspects the detailed configuration of a container
    /// - Parameter name: Container name or ID
    /// - Returns: Container detail model
    public func inspectContainer(name: String) async throws -> ContainerDetail {
        return try await cli.runAndDecodeJSON(arguments: ["inspect", name], type: ContainerDetail.self)
    }
    
    /// Fetches real-time resource utilization stats of containers
    /// - Returns: Stats output string
    public func getStats() async throws -> String {
        return try await cli.run(arguments: ["stats"])
    }
    
    /// Copies files between the host machine and a container
    /// - Parameters:
    ///   - from: Source path (format "container_name:path" if inside container)
    ///   - to: Destination path
    public func copyFile(from: String, to: String) async throws {
        _ = try await cli.run(arguments: ["cp", from, to])
    }
    
    /// Creates a container instance without automatically running it
    public func createContainer(
        image: String,
        name: String?,
        cpus: Int? = nil,
        memory: String? = nil,
        env: [String]? = nil,
        ports: [String]? = nil,
        volumes: [String]? = nil,
        hostname: String? = nil,
        entrypoint: String? = nil,
        autoRemove: Bool = false
    ) async throws {
        var args = ["create"]
        if autoRemove {
            args.append("--rm")
        }
        if let name = name, !name.isEmpty {
            args.append(contentsOf: ["--name", name])
        }
        if let cpus = cpus {
            args.append(contentsOf: ["--cpus", String(cpus)])
        }
        if let memory = memory, !memory.isEmpty {
            args.append(contentsOf: ["--memory", memory])
        }
        if let env = env {
            for e in env where !e.isEmpty {
                args.append(contentsOf: ["-e", e])
            }
        }
        if let ports = ports {
            for p in ports where !p.isEmpty {
                args.append(contentsOf: ["-p", p])
            }
        }
        if let volumes = volumes {
            for v in volumes where !v.isEmpty {
                args.append(contentsOf: ["-v", v])
            }
        }
        if let hostname = hostname, !hostname.isEmpty {
            args.append(contentsOf: ["--hostname", hostname])
        }
        if let entrypoint = entrypoint, !entrypoint.isEmpty {
            args.append(contentsOf: ["--entrypoint", entrypoint])
        }
        args.append(image)
        
        _ = try await cli.run(arguments: args)
    }
    
    /// Creates and runs a container instance
    public func runContainer(
        image: String,
        name: String?,
        cpus: Int? = nil,
        memory: String? = nil,
        env: [String]? = nil,
        ports: [String]? = nil,
        volumes: [String]? = nil,
        hostname: String? = nil,
        entrypoint: String? = nil,
        autoRemove: Bool = false,
        detach: Bool = true
    ) async throws {
        var args = ["run"]
        if detach {
            args.append("-d")
        }
        if autoRemove {
            args.append("--rm")
        }
        if let name = name, !name.isEmpty {
            args.append(contentsOf: ["--name", name])
        }
        if let cpus = cpus {
            args.append(contentsOf: ["--cpus", String(cpus)])
        }
        if let memory = memory, !memory.isEmpty {
            args.append(contentsOf: ["--memory", memory])
        }
        if let env = env {
            for e in env where !e.isEmpty {
                args.append(contentsOf: ["-e", e])
            }
        }
        if let ports = ports {
            for p in ports where !p.isEmpty {
                args.append(contentsOf: ["-p", p])
            }
        }
        if let volumes = volumes {
            for v in volumes where !v.isEmpty {
                args.append(contentsOf: ["-v", v])
            }
        }
        if let hostname = hostname, !hostname.isEmpty {
            args.append(contentsOf: ["--hostname", hostname])
        }
        if let entrypoint = entrypoint, !entrypoint.isEmpty {
            args.append(contentsOf: ["--entrypoint", entrypoint])
        }
        args.append(image)
        
        _ = try await cli.run(arguments: args)
    }
}
