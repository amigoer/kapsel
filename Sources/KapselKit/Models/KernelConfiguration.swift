import Foundation

/// Parsed `[kernel]` section from `container system property list`.
public struct KernelConfiguration: Sendable, Equatable {
    public let sourceURL: URL?
    public let archiveMemberPath: String?
    public let installedFileName: String?
    public let installedFileSize: Int64?
    public let isInstalled: Bool

    public init(
        sourceURL: URL? = nil,
        archiveMemberPath: String? = nil,
        installedFileName: String? = nil,
        installedFileSize: Int64? = nil,
        isInstalled: Bool = false
    ) {
        self.sourceURL = sourceURL
        self.archiveMemberPath = archiveMemberPath
        self.installedFileName = installedFileName
        self.installedFileSize = installedFileSize
        self.isInstalled = isInstalled
    }

    /// Human-readable kernel build label, e.g. `6.18.15-186`.
    public var versionLabel: String? {
        guard let installedFileName, installedFileName.hasPrefix("vmlinux-") else { return nil }
        return String(installedFileName.dropFirst("vmlinux-".count))
    }

    /// Parses property list text and inspects files under `{appRoot}/kernels`.
    public static func load(propertyList: String, appRoot: String) -> KernelConfiguration {
        let parsed = parsePropertyList(propertyList)
        let installed = inspectInstalledKernel(appRoot: appRoot)
        return KernelConfiguration(
            sourceURL: parsed.sourceURL,
            archiveMemberPath: parsed.archiveMemberPath,
            installedFileName: installed?.fileName,
            installedFileSize: installed?.fileSize,
            isInstalled: installed != nil
        )
    }

    private static func parsePropertyList(_ text: String) -> (sourceURL: URL?, archiveMemberPath: String?) {
        var inKernelSection = false
        var sourceURL: URL?
        var archiveMemberPath: String?

        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[kernel]" {
                inKernelSection = true
                continue
            }
            if trimmed.hasPrefix("[") {
                inKernelSection = false
                continue
            }
            guard inKernelSection else { continue }

            if trimmed.hasPrefix("url") {
                sourceURL = quotedValue(from: trimmed).flatMap(URL.init(string:))
            } else if trimmed.hasPrefix("binaryPath") {
                archiveMemberPath = quotedValue(from: trimmed)
            }
        }

        return (sourceURL, archiveMemberPath)
    }

    private static func quotedValue(from line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\""),
              let lastQuote = line.lastIndex(of: "\""),
              firstQuote < lastQuote else {
            return nil
        }
        return String(line[line.index(after: firstQuote)..<lastQuote])
    }

    private static func inspectInstalledKernel(appRoot: String) -> (fileName: String, fileSize: Int64)? {
        let kernelsDir = URL(fileURLWithPath: appRoot, isDirectory: true).appendingPathComponent("kernels")
        let fm = FileManager.default

        guard fm.fileExists(atPath: kernelsDir.path),
              let entries = try? fm.contentsOfDirectory(at: kernelsDir, includingPropertiesForKeys: [.fileSizeKey, .isSymbolicLinkKey]) else {
            return nil
        }

        let defaultLink = entries.first { $0.lastPathComponent.hasPrefix("default.kernel") }
        let resolved: URL? = {
            if let defaultLink {
                return (try? defaultLink.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
                    ? defaultLink.resolvingSymlinksInPath()
                    : defaultLink
            }
            return entries.first { $0.lastPathComponent.hasPrefix("vmlinux-") }
        }()

        guard let resolved, fm.fileExists(atPath: resolved.path) else { return nil }

        let size = (try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        guard size > 0 else { return nil }

        return (resolved.lastPathComponent, size)
    }
}

/// Progress update while installing or removing a kernel.
public struct KernelInstallProgress: Sendable, Equatable {
    public enum Stage: Sendable, Equatable {
        case preparing
        case downloading
        case installing
        case removing
    }

    public let stage: Stage
    /// 0…1 when known (download phase).
    public let fractionCompleted: Double?
    public let detail: String

    public init(stage: Stage, fractionCompleted: Double? = nil, detail: String) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted
        self.detail = detail
    }
}
