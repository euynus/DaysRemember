import CryptoKit
import Darwin
import Foundation

/// Local-only Codable context. Backups and CloudKit payloads keep their portable format.
final class PhotoFileStore {
    static let codingKey = CodingUserInfoKey(rawValue: "DaysRemember.PhotoFileStore")!
    static let repairKey = CodingUserInfoKey(rawValue: "DaysRemember.RepairPhotoFiles")!
    let directory: URL
    private var cached: [String: (reference: String, data: Data, stamp: FileStamp)] = [:]

    private struct FileStamp: Equatable {
        let number: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let changedSeconds: Int
        let changedNanoseconds: Int

        init(url: URL) throws {
            // One stat keeps the per-photo cache check cheap and rejects symlink references.
            var value = stat()
            let result = url.withUnsafeFileSystemRepresentation { path in
                path.map { lstat($0, &value) } ?? -1
            }
            guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            guard value.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadCorruptFile) }
            number = value.st_ino
            size = value.st_size
            modifiedSeconds = value.st_mtimespec.tv_sec
            modifiedNanoseconds = value.st_mtimespec.tv_nsec
            changedSeconds = value.st_ctimespec.tv_sec
            changedNanoseconds = value.st_ctimespec.tv_nsec
        }
    }

    init(directory: URL) { self.directory = directory }

    func encoder(repairCorruptFiles: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        encoder.userInfo[Self.codingKey] = self
        encoder.userInfo[Self.repairKey] = repairCorruptFiles
        return encoder
    }

    func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[Self.codingKey] = self
        return decoder
    }

    func reference(for data: Data, id: String, repairCorruptFiles: Bool = false) throws -> String {
        if let entry = cached[id], entry.data == data,
           (try? FileStamp(url: directory.appendingPathComponent(entry.reference))) == entry.stamp {
            return entry.reference
        }
        let reference = Self.digest(data) + ".photo"
        let url = directory.appendingPathComponent(reference)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let stamp = try FileStamp(url: url)
            let existing = try Data(contentsOf: url)
            guard try FileStamp(url: url) == stamp else { throw CocoaError(.fileReadCorruptFile) }
            if existing != data {
                guard repairCorruptFiles else { throw CocoaError(.fileReadCorruptFile) }
                let retained = directory.appendingPathComponent("Unreadable", isDirectory: true)
                try FileManager.default.createDirectory(at: retained, withIntermediateDirectories: true)
                try existing.write(to: retained.appendingPathComponent(UUID().uuidString + ".photo"), options: .atomic)
                try data.write(to: url, options: .atomic)
                _ = try self.data(for: reference, id: id)
            } else {
                cached[id] = (reference, data, stamp)
            }
        } else {
            if cached[id]?.reference == reference && !repairCorruptFiles {
                throw CocoaError(.fileReadNoSuchFile)
            }
            // Publish the immutable photo before metadata can reference it.
            try data.write(to: url, options: .atomic)
            _ = try self.data(for: reference, id: id)
        }
        return reference
    }

    func data(for reference: String, id: String) throws -> Data {
        guard Self.isValidReference(reference) else { throw CocoaError(.fileReadCorruptFile) }
        let url = directory.appendingPathComponent(reference)
        let stamp = try FileStamp(url: url)
        let data = try Data(contentsOf: url)
        guard Self.digest(data) + ".photo" == reference else { throw CocoaError(.fileReadCorruptFile) }
        guard try FileStamp(url: url) == stamp else { throw CocoaError(.fileReadCorruptFile) }
        cached[id] = (reference, data, stamp)
        return data
    }

    func originalFiles() throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [:] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var original = try Dictionary(uniqueKeysWithValues: files.filter { Self.isValidReference($0.lastPathComponent) }.map {
            ("photos/" + $0.lastPathComponent, try Data(contentsOf: $0))
        })
        let retained = directory.appendingPathComponent("Unreadable", isDirectory: true)
        if FileManager.default.fileExists(atPath: retained.path) {
            for file in try FileManager.default.contentsOfDirectory(at: retained, includingPropertiesForKeys: nil)
                where file.pathExtension == "photo" {
                original["photos/unreadable/" + file.lastPathComponent] = try Data(contentsOf: file)
            }
        }
        return original
    }

    private static func isValidReference(_ reference: String) -> Bool {
        reference.count == 70 && reference.hasSuffix(".photo")
            && reference.prefix(64).utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
