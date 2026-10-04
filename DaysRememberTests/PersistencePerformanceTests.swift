import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import DaysRemember

@MainActor
final class PersistencePerformanceTests: XCTestCase {
    func testPhotoHeavyPersistence10Records() throws { try benchmarkPersistence(recordCount: 10) }
    func testPhotoHeavyPersistence100Records() throws { try benchmarkPersistence(recordCount: 100) }
    func testPhotoHeavyPersistence1000Records() throws { try benchmarkPersistence(recordCount: 1000) }

    func testPhotoHeavyCodecComparison100Records() throws {
        let days = try makeDays(count: 100)
        let codecs: [(name: String, encode: () throws -> Data, decode: (Data) throws -> [Day])] = [
            ("json_default", { try JSONEncoder().encode(days) },
             { try JSONDecoder().decode([Day].self, from: $0) }),
            ("json_without_escaping_slashes", {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .withoutEscapingSlashes
                return try encoder.encode(days)
            }, { try JSONDecoder().decode([Day].self, from: $0) }),
            ("plist_binary", {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                return try encoder.encode(days)
            }, { try PropertyListDecoder().decode([Day].self, from: $0) })
        ]
        var encodeTimes = Array(repeating: [Double](), count: codecs.count)
        var decodeTimes = Array(repeating: [Double](), count: codecs.count)
        var payloadBytes = Array(repeating: 0, count: codecs.count)

        for sample in 0..<3 {
            // Rotate first position so one codec does not always receive the coldest run.
            for offset in codecs.indices {
                let index = (sample + offset) % codecs.count
                let codec = codecs[index]
                try autoreleasepool {
                    let encoded = try timed(codec.encode)
                    let decoded = try timed { try codec.decode(encoded.value) }
                    XCTAssertTrue(decoded.value == days, "\(codec.name) must preserve every field and photo")
                    if sample > 0 { XCTAssertEqual(encoded.value.count, payloadBytes[index]) }
                    payloadBytes[index] = encoded.value.count
                    encodeTimes[index].append(encoded.milliseconds)
                    decodeTimes[index].append(decoded.milliseconds)
                }
            }
        }

        let summary = codecs.indices.map { index in
            "PERSISTENCE_CODEC_BENCH records=100 codec=\(codecs[index].name) samples=3 "
                + photoSummary(days) + " payload_bytes=\(payloadBytes[index]) "
                + timingSummary("encode", encodeTimes[index]) + " "
                + timingSummary("decode", decodeTimes[index])
        }.joined(separator: "\n")
        report(summary, name: "Photo-heavy codec comparison (100 records)")
    }

    private func benchmarkPersistence(recordCount: Int) throws {
        let days = try makeDays(count: recordCount)
        let payload = try autoreleasepool { try JSONEncoder().encode(days) }
        let categories = try JSONEncoder().encode(CategoryDefinition.system)
        var loadTimes: [Double] = []
        var migrationTimes: [Double] = []
        var updateTimes: [Double] = []
        var exportTimes: [Double] = []
        var updatedPayloadBytes = 0
        var backupPayloadBytes = 0
        var blockedExports = 0

        for _ in 0..<3 {
            try autoreleasepool {
                let suite = "PersistencePerformanceTests.\(UUID().uuidString)"
                let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
                defer {
                    defaults.removePersistentDomain(forName: suite)
                    try? FileManager.default.removeItem(at: directory)
                }
                // Seed only the UUID suite; never use SharedStorage or enable cloud sync/settings.
                defaults.set(payload, forKey: "days.v1")
                defaults.set(categories, forKey: "categories.v1")
                defaults.set(Data("[]".utf8), forKey: "deletedDays.v1")
                defaults.set(Data("[]".utf8), forKey: "syncConflicts.v1")

                let legacy = DayStore(defaults: defaults, photoDirectory: directory)
                let migrated = timed { legacy.save() }
                XCTAssertTrue(migrated.value)
                migrationTimes.append(migrated.milliseconds)
                let loaded = timed { DayStore(defaults: defaults, photoDirectory: directory) }
                let store = loaded.value
                XCTAssertNil(store.loadError)
                XCTAssertNil(store.settings)
                XCTAssertEqual(store.days.count, recordCount)
                loadTimes.append(loaded.milliseconds)

                let original = days[recordCount / 2]
                var edited = try XCTUnwrap(store.days.first { $0.id == original.id })
                edited.title = "Edited photo day \(recordCount / 2)"
                // Includes normalization, didSet, encoding, UserDefaults.set and widget reload.
                let updated = timed { store.update(edited) }
                updateTimes.append(updated.milliseconds)
                updatedPayloadBytes = try XCTUnwrap(defaults.data(forKey: "days.v2")).count

                try autoreleasepool {
                    let reloaded = DayStore(defaults: defaults, photoDirectory: directory)
                    XCTAssertNil(reloaded.loadError)
                    XCTAssertEqual(reloaded.days.map(\.id), days.map(\.id))
                    let persisted = try XCTUnwrap(reloaded.days.first { $0.id == edited.id })
                    XCTAssertEqual(persisted.title, edited.title)
                    XCTAssertEqual(persisted.photoData, original.photoData)
                    XCTAssertTrue(zip(reloaded.days, days).allSatisfy { $0.photoData == $1.photoData },
                                  "The full-array write must also preserve all untouched photos")
                }

                do {
                    let exported = try timed { try store.exportBackup() }
                    exportTimes.append(exported.milliseconds)
                    backupPayloadBytes = exported.value.count
                    XCTAssertLessThanOrEqual(backupPayloadBytes, DayBackup.maximumBytes)
                    let backup = try autoreleasepool { try DayBackup.decode(exported.value) }
                    XCTAssertTrue(backup.days == store.days, "Export must include the edited title and photos")
                } catch DayBackup.BackupError.tooLarge {
                    // Only the documented size cap is expected; all other export errors propagate.
                    // Encode without the cap once to prove this is a legitimate refusal.
                    if blockedExports == 0 {
                        backupPayloadBytes = try autoreleasepool {
                            try JSONEncoder().encode(DayBackup(
                                days: store.days, categories: store.categories,
                                deletedDays: store.deletedDays, syncConflicts: store.syncConflicts
                            )).count
                        }
                        XCTAssertGreaterThan(backupPayloadBytes, DayBackup.maximumBytes)
                    }
                    blockedExports += 1
                }
            }
        }

        XCTAssertTrue(blockedExports == 0 || blockedExports == 3, "Export eligibility must be consistent")
        let exportSummary: String
        if blockedExports == 3 {
            exportSummary = "export_status=blocked_by_backup_size_cap export_median_ms=not_measured "
                + "export_samples=0 cap_refusals=3"
        } else {
            XCTAssertEqual(exportTimes.count, 3)
            exportSummary = "export_status=ok " + timingSummary("export", exportTimes)
        }
        let summary = "PERSISTENCE_BENCH records=\(recordCount) samples=3 " + photoSummary(days)
            + " initial_days_payload_bytes=\(payload.count) updated_days_payload_bytes=\(updatedPayloadBytes)"
            + " backup_payload_bytes=\(backupPayloadBytes) backup_cap_bytes=\(DayBackup.maximumBytes) "
            + timingSummary("migration", migrationTimes) + " "
            + timingSummary("load", loadTimes) + " " + timingSummary("update", updateTimes) + " "
            + exportSummary + "\n"
            + "Scope: UUID suite and warm photo files; one-time migration measured separately; "
            + "synchronous update including widget reload, not fsync; "
            + "settings/cloud sync off. Setup, reload checks and cleanup are untimed."
        report(summary, name: "Photo-heavy persistence (\(recordCount) records)")
    }

    private func makeDays(count: Int) throws -> [Day] {
        let jpeg = try makeJPEG()
        XCTAssertEqual(Array(jpeg.suffix(2)), [0xff, 0xd9])
        let days = try (0..<count).map { index in
            try autoreleasepool {
                // A COM segment before EOI keeps a valid JPEG and prevents binary-plist Data deduplication.
                let comment = Data("DaysRemember persistence photo \(index)".utf8)
                let length = UInt16(comment.count + 2)
                var photo = Data(jpeg.dropLast(2))
                photo.append(contentsOf: [0xff, 0xfe, UInt8(length >> 8), UInt8(length & 0xff)])
                photo.append(comment)
                photo.append(contentsOf: [0xff, 0xd9])
                let source = try XCTUnwrap(CGImageSourceCreateWithData(photo as CFData, nil))
                XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source, 0, nil))
                return Day(id: "persistence.photo.\(index)", title: "Photo day \(index)",
                           date: Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86400),
                           category: .life, photo: .home, photoData: photo)
            }
        }
        XCTAssertEqual(Set(days.compactMap(\.photoData)).count, count, "Every record needs distinct photo bytes")
        return days
    }

    private func makeJPEG() throws -> Data {
        // Fixed pixels, sRGB and JPEG quality are reproducible on the same OS/ImageIO encoder.
        let side = 512
        var state: UInt32 = 0x50484f54
        var pixels = [UInt8](repeating: 0, count: side * side * 3)
        for index in pixels.indices {
            state = 1_664_525 &* state &+ 1_013_904_223
            pixels[index] = UInt8(state >> 24)
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let image = try XCTUnwrap(CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: side * 3,
            space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.4] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        XCTAssertTrue((64 * 1024...128 * 1024 - 128).contains(data.length), "JPEG fixture size, not a timing threshold")
        return data as Data
    }

    private func timed<Value>(_ body: () throws -> Value) rethrows -> (value: Value, milliseconds: Double) {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try autoreleasepool(invoking: body)
        let elapsed = start.duration(to: clock.now).components
        return (value, Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
    }

    private func timingSummary(_ operation: String, _ samples: [Double]) -> String {
        let median = samples.isEmpty ? "not_measured" : String(samples.sorted()[samples.count / 2])
        return "\(operation)_median_ms=\(median) \(operation)_samples_ms=\(samples)"
    }

    private func photoSummary(_ days: [Day]) -> String {
        let sizes = days.compactMap { $0.photoData?.count }
        return "photo_bytes_min=\(sizes.min() ?? 0) photo_bytes_max=\(sizes.max() ?? 0) "
            + "photo_bytes_total=\(sizes.reduce(0, +)) distinct_photos=\(days.count)"
    }

    private func report(_ summary: String, name: String) {
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
