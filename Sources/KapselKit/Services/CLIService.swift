import Foundation

/// Error definitions representing possible failures during interactions with the container CLI
public enum CLIError: LocalizedError, Sendable {
    /// CLI executable not found
    case cliNotFound(path: String)
    /// Execution failed with a non-zero exit code
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    /// Failed to decode JSON output from CLI
    case decodingFailed(details: String)
    /// Output format is invalid
    case invalidOutput
    
    public var errorDescription: String? {
        switch self {
        case .cliNotFound(let path):
            return "The container CLI executable was not found at \(path). Please verify your installation and paths."
        case .executionFailed(let command, let exitCode, let stderr):
            return "Command '\(command)' failed with exit code \(exitCode). Details: \(stderr)"
        case .decodingFailed(let details):
            return "Failed to decode JSON response from CLI: \(details)"
        case .invalidOutput:
            return "The command line output format is invalid."
        }
    }
}

/// Core service responsible for launching and interacting with the apple/container command line tool
public final class CLIService: Sendable {
    
    /// Shared singleton instance of CLIService
    public static let shared = CLIService()
    
    /// UserDefaults key for custom CLI path configuration
    private static let cliPathKey = "com.kapsel.cliPath"
    
    /// Get or set the container CLI path (defaults to the first known install location)
    public var cliPath: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: Self.cliPathKey),
               FileManager.default.fileExists(atPath: stored) {
                return stored
            }
            return EngineInstallService.shared.findInstalledCLIPath()
                ?? EngineInstallService.candidateCLIPaths[0]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.cliPathKey)
        }
    }

    /// Whether the configured CLI binary exists on disk
    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: cliPath)
            || EngineInstallService.shared.isCLIInstalled()
    }
    
    public init() {}
    
    /// Executes a container CLI command asynchronously and returns the stdout
    /// - Parameter arguments: List of command line arguments
    /// - Returns: Standard output string
    public func run(arguments: [String]) async throws -> String {
        let path = self.cliPath
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.cliNotFound(path: path)
        }
        
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            do {
                try process.run()
            } catch {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                )
            }
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: process.terminationStatus,
                    stderr: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            
            return output
        }.value
    }
    
    /// Stream CLI stdout asynchronously block by block (suitable for logs)
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - onOutput: Callback closure triggered when new stdout chunks are available
    /// - Returns: Process termination status code
    @discardableResult
    public func runStream(
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        let path = self.cliPath
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.cliNotFound(path: path)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    onOutput(output)
                }
            }
            
            final class DataAccumulator: @unchecked Sendable {
                private let lock = NSLock()
                private var data = Data()
                func append(_ other: Data) {
                    lock.withLock { data.append(other) }
                }
                var currentData: Data {
                    lock.withLock { data }
                }
            }
            
            let stderrAccumulator = DataAccumulator()
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stderrAccumulator.append(data)
                }
            }
            
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                
                if proc.terminationStatus != 0 {
                    let errStr = String(data: stderrAccumulator.currentData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: CLIError.executionFailed(
                        command: "container \(arguments.joined(separator: " "))",
                        exitCode: proc.terminationStatus,
                        stderr: errStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                } else {
                    continuation.resume(returning: proc.terminationStatus)
                }
            }
            
            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                ))
            }
        }
    }
    
    /// Executes a command with standard input integration (e.g. exec commands)
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - input: Stdin string input
    /// - Returns: Standard output string
    public func runWithInput(arguments: [String], input: String) async throws -> String {
        let path = self.cliPath
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.cliNotFound(path: path)
        }
        
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            do {
                try process.run()
            } catch {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                )
            }
            
            if let data = input.data(using: .utf8) {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
            }
            try? stdinPipe.fileHandleForWriting.close()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: process.terminationStatus,
                    stderr: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            
            return output
        }.value
    }
    
    /// Executes a command and returns stdout even when the process exits non-zero
    public func runAllowingFailure(arguments: [String]) async throws -> (output: String, exitCode: Int32) {
        let path = self.cliPath

        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.cliNotFound(path: path)
        }

        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                )
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let output = String(data: stdoutData, encoding: .utf8) ?? ""
            let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               process.terminationStatus != 0 {
                throw CLIError.executionFailed(
                    command: "container \(arguments.joined(separator: " "))",
                    exitCode: process.terminationStatus,
                    stderr: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            return (output, process.terminationStatus)
        }.value
    }

    /// Executes a command and decodes JSON output into a Decodable structure
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - type: Target Decodable type
    /// - Returns: Decoded model
    public func runAndDecodeJSON<T: Decodable>(arguments: [String], type: T.Type) async throws -> T {
        var fullArguments = arguments
        
        if !fullArguments.contains("--format") {
            fullArguments.append(contentsOf: ["--format", "json"])
        }
        
        let rawOutput = try await run(arguments: fullArguments)
        guard let data = rawOutput.data(using: .utf8) else {
            throw CLIError.invalidOutput
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw CLIError.decodingFailed(details: "\(error.localizedDescription). Raw output: \(rawOutput)")
        }
    }
}
