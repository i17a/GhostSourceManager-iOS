import Foundation
import Compression

struct AnalyzedIPA {
    let fileURL: URL
    let fileName: String
    let fileSize: Int64
    let appName: String
    let bundleIdentifier: String
    let shortVersion: String
    let buildVersion: String
    let minimumOSVersion: String?
    let iconPNGData: Data?
}

enum IPAAnalyzerError: LocalizedError {
    case invalidExtension
    case unreadableArchive
    case missingInfoPlist
    case malformedInfoPlist

    var errorDescription: String? {
        switch self {
        case .invalidExtension:
            return "الملف المختار ليس بصيغة .ipa."
        case .unreadableArchive:
            return "تعذّر فتح أرشيف IPA أو أن الملف تالف."
        case .missingInfoPlist:
            return "لم يتم العثور على Payload/*.app/Info.plist داخل ملف الـ IPA."
        case .malformedInfoPlist:
            return "تعذّر قراءة بيانات Info.plist المستخرجة."
        }
    }
}

/// Pure Foundation + Apple Compression framework ZIP reader tailored for .ipa inspection without external dependencies.
enum IPAAnalyzerService {
    static func analyze(fileURL: URL) throws -> AnalyzedIPA {
        guard fileURL.pathExtension.lowercased() == "ipa" else {
            throw IPAAnalyzerError.invalidExtension
        }

        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }

        let archiveData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard archiveData.count > 22 else {
            throw IPAAnalyzerError.unreadableArchive
        }

        let entries = try listZipCentralDirectory(data: archiveData)
        guard let plistEntry = entries.first(where: { entry in
            let parts = entry.name.split(separator: "/")
            return parts.count == 3 && parts[0] == "Payload" && parts[1].hasSuffix(".app") && parts[2] == "Info.plist"
        }) else {
            throw IPAAnalyzerError.missingInfoPlist
        }

        let plistData = try extractZipEntry(plistEntry, from: archiveData)
        guard let plistAny = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let plist = plistAny as? [String: Any] else {
            throw IPAAnalyzerError.malformedInfoPlist
        }

        let fallbackName = fileURL.deletingPathExtension().lastPathComponent
        let appName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? (plist["CFBundleExecutable"] as? String)
            ?? fallbackName
        let bundleID = (plist["CFBundleIdentifier"] as? String) ?? "com.app.\(fallbackName.lowercased())"
        let shortVer = (plist["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildVer = (plist["CFBundleVersion"] as? String) ?? shortVer
        let minOS = plist["MinimumOSVersion"] as? String

        let iconCandidates = entries
            .filter { e in
                e.name == "iTunesArtwork" ||
                (e.name.hasPrefix("Payload/") && e.name.lowercased().contains("icon") && e.name.lowercased().hasSuffix(".png"))
            }
            .sorted { $0.uncompressedSize > $1.uncompressedSize }

        var extractedIcon: Data?
        for candidate in iconCandidates {
            if let bytes = try? extractZipEntry(candidate, from: archiveData), isStandardPNG(bytes) {
                extractedIcon = bytes
                break
            }
        }

        return AnalyzedIPA(
            fileURL: fileURL,
            fileName: fileURL.lastPathComponent,
            fileSize: Int64(archiveData.count),
            appName: appName,
            bundleIdentifier: bundleID,
            shortVersion: shortVer,
            buildVersion: buildVer,
            minimumOSVersion: minOS,
            iconPNGData: extractedIcon
        )
    }

    private struct ZipEntry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static func listZipCentralDirectory(data: Data) throws -> [ZipEntry] {
        // Locate End of Central Directory (0x06054b50)
        let maxComment = min(data.count, 65557)
        var eocdOffset: Int?
        for idx in stride(from: data.count - 22, through: max(0, data.count - maxComment), by: -1) {
            if readUInt32LE(data, idx) == 0x06054b50 {
                eocdOffset = idx
                break
            }
        }
        guard let eocd = eocdOffset else { throw IPAAnalyzerError.unreadableArchive }

        let totalEntries = Int(readUInt16LE(data, eocd + 10))
        let cdOffset = Int(readUInt32LE(data, eocd + 16))
        var cursor = cdOffset
        var entries: [ZipEntry] = []

        for _ in 0..<totalEntries {
            guard cursor + 46 <= data.count, readUInt32LE(data, cursor) == 0x02014b50 else { break }
            let method = readUInt16LE(data, cursor + 10)
            let compSize = Int(readUInt32LE(data, cursor + 20))
            let uncompSize = Int(readUInt32LE(data, cursor + 24))
            let nameLen = Int(readUInt16LE(data, cursor + 28))
            let extraLen = Int(readUInt16LE(data, cursor + 30))
            let commentLen = Int(readUInt16LE(data, cursor + 32))
            let localOffset = Int(readUInt32LE(data, cursor + 42))

            let nameStart = cursor + 46
            guard nameStart + nameLen <= data.count else { break }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? ""

            entries.append(
                ZipEntry(
                    name: name,
                    compressionMethod: method,
                    compressedSize: compSize,
                    uncompressedSize: uncompSize,
                    localHeaderOffset: localOffset
                )
            )
            cursor = nameStart + nameLen + extraLen + commentLen
        }
        return entries
    }

    private static func extractZipEntry(_ entry: ZipEntry, from data: Data) throws -> Data {
        let loc = entry.localHeaderOffset
        guard loc + 30 <= data.count, readUInt32LE(data, loc) == 0x04034b50 else {
            throw IPAAnalyzerError.unreadableArchive
        }
        let nameLen = Int(readUInt16LE(data, loc + 26))
        let extraLen = Int(readUInt16LE(data, loc + 28))
        let payloadStart = loc + 30 + nameLen + extraLen
        guard payloadStart + entry.compressedSize <= data.count else {
            throw IPAAnalyzerError.unreadableArchive
        }
        let slice = data.subdata(in: payloadStart..<(payloadStart + entry.compressedSize))

        if entry.compressionMethod == 0 {
            return slice
        }
        if entry.compressionMethod == 8 {
            let dstCapacity = max(entry.uncompressedSize, 4096)
            var output = Data(count: dstCapacity)
            let written = output.withUnsafeMutableBytes { dstPtr -> Int in
                slice.withUnsafeBytes { srcPtr -> Int in
                    guard let dstBase = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    return compression_decode_buffer(
                        dstBase,
                        dstCapacity,
                        srcBase,
                        slice.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            guard written > 0 else { throw IPAAnalyzerError.unreadableArchive }
            output.count = written
            return output
        }
        throw IPAAnalyzerError.unreadableArchive
    }

    private static func isStandardPNG(_ data: Data) -> Bool {
        guard data.count > 24 else { return false }
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        for (i, b) in sig.enumerated() where data[i] != b { return false }
        let chunkType = String(data: data.subdata(in: 12..<16), encoding: .ascii)
        return chunkType != "CgBI"
    }

    private static func readUInt16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
