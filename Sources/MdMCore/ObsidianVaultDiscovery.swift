import Foundation

public struct ObsidianVaultLocation: Equatable, Sendable {
    public let vaultDirectoryPath: String

    public init(vaultDirectoryPath: String) {
        let expanded = NSString(string: vaultDirectoryPath).expandingTildeInPath
        self.vaultDirectoryPath = URL(filePath: expanded, directoryHint: .isDirectory)
            .standardizedFileURL
            .path(percentEncoded: false)
    }

    public var attachmentResourceDirectoryPath: String {
        URL(filePath: vaultDirectoryPath, directoryHint: .isDirectory)
            .appendingPathComponent("_resources")
            .path(percentEncoded: false)
    }

    public var dailyReferenceDirectoryPath: String {
        URL(filePath: vaultDirectoryPath, directoryHint: .isDirectory)
            .appendingPathComponent("daily")
            .path(percentEncoded: false)
    }
}

public struct ObsidianVaultDiscovery {
    private struct Configuration: Decodable {
        let vaults: [String: VaultRecord]
    }

    private struct VaultRecord: Decodable {
        let path: String
        let open: Bool?
        let ts: Double?
    }

    private struct Candidate {
        let location: ObsidianVaultLocation
        let isOpen: Bool
        let lastOpenedAt: Double
    }

    private let configurationURL: URL
    private let fileManager: FileManager

    public init(
        configurationURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.configurationURL = configurationURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("obsidian", isDirectory: true)
            .appendingPathComponent("obsidian.json", isDirectory: false)
    }

    public func preferredVault() -> ObsidianVaultLocation? {
        guard let data = try? Data(contentsOf: configurationURL),
              let configuration = try? JSONDecoder().decode(Configuration.self, from: data) else {
            return nil
        }

        let candidates = configuration.vaults.values.compactMap { record -> Candidate? in
            let decodedPath = record.path.removingPercentEncoding ?? record.path
            let location = ObsidianVaultLocation(vaultDirectoryPath: decodedPath)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: location.vaultDirectoryPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }

            return Candidate(
                location: location,
                isOpen: record.open == true,
                lastOpenedAt: record.ts ?? 0
            )
        }

        return candidates.sorted { lhs, rhs in
            if lhs.isOpen != rhs.isOpen {
                return lhs.isOpen
            }
            if lhs.lastOpenedAt != rhs.lastOpenedAt {
                return lhs.lastOpenedAt > rhs.lastOpenedAt
            }
            return lhs.location.vaultDirectoryPath.localizedStandardCompare(rhs.location.vaultDirectoryPath) == .orderedAscending
        }.first?.location
    }
}
