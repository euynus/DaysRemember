import CryptoKit
import Foundation
import XCTest
@testable import DaysRemember

final class PhotoFileStoreTests: XCTestCase {
    func testIdenticalBytesDeduplicateAcrossIDsAndStoreInstances() throws {
        try withStore { store in
            let bytes = Data([1, 2, 3, 4])
            let reference = try store.reference(for: bytes, id: "first")
            XCTAssertEqual(reference, expectedReference(for: bytes))
            let url = store.directory.appendingPathComponent(reference)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_600_000_000)],
                                                  ofItemAtPath: url.path)
            let modified = try modificationDate(of: url)

            XCTAssertEqual(try store.reference(for: bytes, id: "second"), reference)
            let reloaded = PhotoFileStore(directory: store.directory)
            XCTAssertEqual(try reloaded.reference(for: bytes, id: "third"), reference)
            XCTAssertEqual(try reloaded.data(for: reference, id: "fourth"), bytes)

            XCTAssertEqual(try fileNames(in: store.directory), [reference])
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(try modificationDate(of: url), modified)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeRegular)
        }
    }

    func testChangedBytesUnderSameIDPreserveOldContentAddressedFile() throws {
        try withStore { store in
            let original = Data([1, 2, 3])
            let changed = Data([4, 5, 6])
            let oldReference = try store.reference(for: original, id: "same-day")
            let newReference = try store.reference(for: changed, id: "same-day")

            XCTAssertEqual(oldReference, expectedReference(for: original))
            XCTAssertEqual(newReference, expectedReference(for: changed))
            XCTAssertNotEqual(oldReference, newReference)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent(oldReference)), original)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent(newReference)), changed)

            let reloaded = PhotoFileStore(directory: store.directory)
            XCTAssertEqual(try reloaded.data(for: oldReference, id: "same-day"), original)
            XCTAssertEqual(try reloaded.data(for: newReference, id: "same-day"), changed)
            XCTAssertEqual(try store.reference(for: original, id: "same-day"), oldReference)
            XCTAssertEqual(try fileNames(in: store.directory), [oldReference, newReference].sorted())
        }
    }

    func testMalformedAndEscapingReferencesAreRejectedBeforeFileAccess() throws {
        try withStore { store in
            let bytes = Data([1, 2, 3])
            let reference = expectedReference(for: bytes)
            let outside = store.directory.deletingLastPathComponent().appendingPathComponent(reference)
            try bytes.write(to: outside)
            let malformed = [
                "",
                String(repeating: "a", count: 63) + ".photo",
                String(repeating: "a", count: 65) + ".photo",
                "g" + String(reference.dropFirst()),
                String(reference.prefix(64)).uppercased() + ".photo",
                String(reference.prefix(64)) + ".PHOTO",
                "../" + reference,
                "../" + String(repeating: "a", count: 61) + ".photo",
                "./" + reference,
                "nested/" + reference,
                reference + "/..",
                outside.path
            ]

            for directoryExists in [false, true] {
                if directoryExists {
                    try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
                }
                for value in malformed {
                    XCTAssertThrowsError(try store.data(for: value, id: "day"), value) { error in
                        XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile, value)
                    }
                }
                XCTAssertEqual(FileManager.default.fileExists(atPath: store.directory.path), directoryExists)
                if directoryExists { XCTAssertEqual(try fileNames(in: store.directory), []) }
                XCTAssertEqual(try Data(contentsOf: outside), bytes)
            }
        }
    }

    func testSymlinkCannotReplaceRegularPhotoForReadsOrWrites() throws {
        try withStore { store in
            let bytes = Data([1, 2, 3])
            let reference = try store.reference(for: bytes, id: "day")
            let url = store.directory.appendingPathComponent(reference)
            let outside = store.directory.deletingLastPathComponent().appendingPathComponent("outside.photo")
            try bytes.write(to: outside)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)

            for reader in [store, PhotoFileStore(directory: store.directory)] {
                XCTAssertThrowsError(try reader.data(for: reference, id: "day")) { error in
                    XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
                }
                XCTAssertThrowsError(try reader.reference(for: bytes, id: "day")) { error in
                    XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
                }
            }

            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: url.path), outside.path)
            XCTAssertEqual(try Data(contentsOf: outside), bytes)
            XCTAssertEqual(try fileNames(in: store.directory), [reference])
        }
    }

    func testDirectoryCannotReplaceRegularPhotoForReadsOrWrites() throws {
        try withStore { store in
            let bytes = Data([1, 2, 3])
            let reference = try store.reference(for: bytes, id: "day")
            let url = store.directory.appendingPathComponent(reference)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let retained = url.appendingPathComponent("retained.bin")
            let retainedBytes = Data([9, 8, 7])
            try retainedBytes.write(to: retained)

            for reader in [store, PhotoFileStore(directory: store.directory)] {
                XCTAssertThrowsError(try reader.data(for: reference, id: "day")) { error in
                    XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
                }
                XCTAssertThrowsError(try reader.reference(for: bytes, id: "day")) { error in
                    XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
                }
            }

            XCTAssertEqual(try Data(contentsOf: retained), retainedBytes)
            XCTAssertEqual(try fileNames(in: url), ["retained.bin"])
            XCTAssertEqual(try fileNames(in: store.directory), [reference])
        }
    }

    func testCachedReadRevalidatesBytesDespiteUnchangedSizeAndModificationDate() throws {
        try withStore { store in
            let original = Data([1, 2, 3])
            let damaged = Data([9, 8, 7])
            let reference = try store.reference(for: original, id: "day")
            let url = store.directory.appendingPathComponent(reference)
            let modified = Date(timeIntervalSince1970: 1_600_000_000)
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
            XCTAssertEqual(try store.data(for: reference, id: "day"), original)

            try damaged.write(to: url)
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
            XCTAssertEqual(try modificationDate(of: url), modified)
            XCTAssertThrowsError(try store.data(for: reference, id: "day")) { error in
                XCTAssertEqual((error as? CocoaError)?.code, .fileReadCorruptFile)
            }
            XCTAssertEqual(try Data(contentsOf: url), damaged)
            XCTAssertEqual(try fileNames(in: store.directory), [reference])

            try original.write(to: url, options: .atomic)
            XCTAssertEqual(try store.data(for: reference, id: "day"), original)
        }
    }

    func testMissingReadsDoNotReturnCachedBytesOrRecreateStorage() throws {
        try withStore { store in
            let bytes = Data([1, 2, 3])
            let reference = try store.reference(for: bytes, id: "day")
            let url = store.directory.appendingPathComponent(reference)
            try FileManager.default.removeItem(at: url)

            for reader in [store, PhotoFileStore(directory: store.directory)] {
                XCTAssertThrowsError(try reader.data(for: reference, id: "day")) { error in
                    XCTAssertEqual((error as? POSIXError)?.code, .ENOENT)
                }
            }
            XCTAssertEqual(try fileNames(in: store.directory), [])

            try FileManager.default.removeItem(at: store.directory)
            XCTAssertThrowsError(try store.data(for: reference, id: "day")) { error in
                XCTAssertEqual((error as? POSIXError)?.code, .ENOENT)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path))
            XCTAssertEqual(try fileNames(in: store.directory.deletingLastPathComponent()), [])
        }
    }

    private func withStore(_ body: (PhotoFileStore) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoFileStoreTests.\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(PhotoFileStore(directory: root.appendingPathComponent("photos", isDirectory: true)))
    }

    private func expectedReference(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + ".photo"
    }

    private func fileNames(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    private func modificationDate(of url: URL) throws -> Date {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.modificationDate] as? Date)
    }
}
