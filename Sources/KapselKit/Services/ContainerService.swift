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
        args.append(contentsOf: ["--format", "json"])
        let raw = try await cli.run(arguments: args)
        return Self.parseContainers(from: raw)
    }

    /// Parses `container ls --format json` output, tolerating the nested
    /// `configuration` shape and both string / object `status` variants.
    static func parseContainers(from raw: String) -> [Container] {
        guard let data = raw.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { parseContainer(from: $0) }
    }

    private static func parseContainer(from dict: [String: Any]) -> Container? {
        let config = dict["configuration"] as? [String: Any] ?? dict

        let id = (config["id"] as? String) ?? (dict["id"] as? String) ?? ""
        guard !id.isEmpty else { return nil }

        var image = ""
        if let imageObj = config["image"] as? [String: Any] {
            image = imageObj["reference"] as? String ?? ""
        } else if let imageStr = config["image"] as? String {
            image = imageStr
        }

        var os = "linux"
        var arch = "arm64"
        if let platform = config["platform"] as? [String: Any] {
            os = platform["os"] as? String ?? os
            arch = platform["architecture"] as? String ?? arch
        }

        var cpus: Int?
        var memory: String?
        if let resources = config["resources"] as? [String: Any] {
            cpus = (resources["cpus"] as? NSNumber)?.intValue
            if let memBytes = (resources["memoryInBytes"] as? NSNumber)?.int64Value {
                memory = formatMemory(memBytes)
            }
        }

        var status = Container.Status.unknown
        var address: String?

        if let statusStr = dict["status"] as? String {
            status = Container.Status(rawValue: statusStr) ?? .unknown
        } else if let statusObj = dict["status"] as? [String: Any] {
            let state = (statusObj["state"] as? String) ?? "unknown"
            status = Container.Status(rawValue: state) ?? .unknown
            address = firstAddress(in: statusObj["networks"])
        }

        if address == nil {
            address = firstAddress(in: dict["networks"]) ?? firstAddress(in: config["networks"])
        }

        let createdAt = config["creationDate"] as? String

        return Container(
            containerID: id,
            name: id,
            image: image,
            status: status,
            address: address,
            createdAt: createdAt,
            os: os,
            arch: arch,
            cpus: cpus,
            memory: memory
        )
    }

    private static func firstAddress(in networks: Any?) -> String? {
        guard let entries = networks as? [[String: Any]] else { return nil }
        for entry in entries {
            if let address = entry["address"] as? String, !address.isEmpty {
                return address
            }
        }
        return nil
    }

    private static func formatMemory(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: gb.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fG" : "%.1fG", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0fM", mb)
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
