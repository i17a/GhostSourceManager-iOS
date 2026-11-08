import Foundation

struct SourceAppItem: Identifiable, Equatable {
    let id: String
    let index: Int
    var name: String
    var bundleIdentifier: String
    var developerName: String
    var version: String
    var buildVersion: String
    var versionDate: String
    var localizedDescription: String
    var hasExplicitDescription: Bool
    var downloadURL: String
    var iconURL: String
    var size: Int64
}

struct ParsedSourceManifest {
    var name: String
    var identifier: String
    var subtitle: String
    var appsKey: String
    var apps: [SourceAppItem]
    /// Preserves all unknown root keys and nested app keys untouched when saving back
    var rawRootObject: [String: Any]
}

enum SourceManifestError: LocalizedError {
    case invalidUTF8
    case malformedJSON(String)
    case invalidRootStructure

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "تعذّر قراءة ترميز UTF-8 لملف السورس."
        case .malformedJSON(let detail):
            return "ملف JSON غير صالح: \(detail)"
        case .invalidRootStructure:
            return "يجب أن يكون جذر ملف السورس كائناً JSON أو مصفوفة تطبيقات."
        }
    }
}

enum SourceManifestCoder {
    static func parse(jsonString: String) throws -> ParsedSourceManifest {
        guard let data = jsonString.data(using: .utf8) else {
            throw SourceManifestError.invalidUTF8
        }
        let rawAny: Any
        do {
            rawAny = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw SourceManifestError.malformedJSON(error.localizedDescription)
        }

        var rootDict: [String: Any]
        var appsKey = "apps"
        if let dict = rawAny as? [String: Any] {
            rootDict = dict
            if rootDict["apps"] as? [Any] == nil {
                if let candidate = rootDict.first(where: { $0.value is [[String: Any]] })?.key {
                    appsKey = candidate
                } else {
                    rootDict["apps"] = []
                }
            }
        } else if let arr = rawAny as? [[String: Any]] {
            rootDict = ["name": "Ghost Source", "apps": arr]
        } else {
            throw SourceManifestError.invalidRootStructure
        }

        let rawApps = (rootDict[appsKey] as? [[String: Any]]) ?? []
        var items: [SourceAppItem] = []

        for (idx, obj) in rawApps.enumerated() {
            let versions = obj["versions"] as? [[String: Any]]
            let latestVer = versions?.first

            let directDesc = (obj["localizedDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let verDesc = (latestVer?["localizedDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasExplicit = !(directDesc ?? "").isEmpty || !(verDesc ?? "").isEmpty
            let resolvedDesc = directDesc ?? verDesc ?? (obj["subtitle"] as? String) ?? ""

            let version = (obj["version"] as? String) ?? (latestVer?["version"] as? String) ?? "1.0.0"
            let buildVersion = (obj["buildVersion"] as? String) ?? (latestVer?["buildVersion"] as? String) ?? version
            let versionDate = (obj["versionDate"] as? String) ?? (latestVer?["date"] as? String) ?? ISO8601DateFormatter().string(from: Date())
            let downloadURL = (obj["downloadURL"] as? String) ?? (latestVer?["downloadURL"] as? String) ?? ""
            let iconURL = (obj["iconURL"] as? String) ?? ""

            let sizeVal: Int64
            if let n = obj["size"] as? NSNumber {
                sizeVal = n.int64Value
            } else if let n = latestVer?["size"] as? NSNumber {
                sizeVal = n.int64Value
            } else {
                sizeVal = 0
            }

            let bundleID = (obj["bundleIdentifier"] as? String) ?? (obj["bundleID"] as? String) ?? ""
            items.append(
                SourceAppItem(
                    id: "\(bundleID)-\(idx)",
                    index: idx,
                    name: (obj["name"] as? String) ?? "تطبيق بدون اسم",
                    bundleIdentifier: bundleID,
                    developerName: (obj["developerName"] as? String) ?? "Developer",
                    version: version,
                    buildVersion: buildVersion,
                    versionDate: versionDate,
                    localizedDescription: resolvedDesc,
                    hasExplicitDescription: hasExplicit,
                    downloadURL: downloadURL,
                    iconURL: iconURL,
                    size: sizeVal
                )
            )
        }

        return ParsedSourceManifest(
            name: (rootDict["name"] as? String) ?? "Ghost Source",
            identifier: (rootDict["identifier"] as? String) ?? "",
            subtitle: (rootDict["subtitle"] as? String) ?? "",
            appsKey: appsKey,
            apps: items,
            rawRootObject: rootDict
        )
    }

    static func upsertApp(
        in manifest: ParsedSourceManifest,
        existingIndex: Int?,
        name: String,
        bundleIdentifier: String,
        developerName: String,
        version: String,
        buildVersion: String,
        localizedDescription: String,
        downloadURL: String,
        iconURL: String,
        size: Int64,
        minOSVersion: String?
    ) throws -> (jsonString: String, appliedDefaults: [String], updated: ParsedSourceManifest) {
        var appliedDefaults: [String] = []
        var rootCopy = manifest.rawRootObject
        var rawApps = (rootCopy[manifest.appsKey] as? [[String: Any]]) ?? []

        let targetIdx: Int? = existingIndex ?? rawApps.firstIndex(where: {
            (($0["bundleIdentifier"] as? String) ?? "").lowercased() == bundleIdentifier.lowercased()
        })

        var entry: [String: Any] = (targetIdx != nil && targetIdx! < rawApps.count) ? rawApps[targetIdx!] : [:]

        let trimmedDesc = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = trimmedDesc.isEmpty ? "\(name) لنظام iOS" : trimmedDesc
        if trimmedDesc.isEmpty {
            appliedDefaults.append("تمت إضافة وصف افتراضي لحقل localizedDescription لضمان التوافق.")
        }

        let trimmedDev = developerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDev = trimmedDev.isEmpty ? ((entry["developerName"] as? String) ?? manifest.name) : trimmedDev
        if trimmedDev.isEmpty && entry["developerName"] == nil {
            appliedDefaults.append("تم تعيين developerName الافتراضي إلى \(finalDev).")
        }

        let nowISO = ISO8601DateFormatter().string(from: Date())
        entry["name"] = name
        entry["bundleIdentifier"] = bundleIdentifier
        entry["developerName"] = finalDev
        entry["version"] = version
        entry["buildVersion"] = buildVersion.isEmpty ? version : buildVersion
        entry["versionDate"] = nowISO
        entry["localizedDescription"] = finalDesc
        entry["downloadURL"] = downloadURL
        entry["size"] = size
        if !iconURL.isEmpty {
            entry["iconURL"] = iconURL
        }

        var versionRecord: [String: Any] = [
            "version": version,
            "buildVersion": buildVersion.isEmpty ? version : buildVersion,
            "date": nowISO,
            "localizedDescription": finalDesc,
            "downloadURL": downloadURL,
            "size": size
        ]
        if let minOSVersion, !minOSVersion.isEmpty {
            versionRecord["minOSVersion"] = minOSVersion
        }

        if var versions = entry["versions"] as? [[String: Any]] {
            versions.removeAll { ($0["version"] as? String) == version }
            versions.insert(versionRecord, at: 0)
            entry["versions"] = versions
        } else if targetIdx == nil {
            entry["versions"] = [versionRecord]
        }

        if let idx = targetIdx, idx < rawApps.count {
            rawApps[idx] = entry
        } else {
            rawApps.insert(entry, at: 0)
        }

        rootCopy[manifest.appsKey] = rawApps
        let jsonString = try serializePretty(rootCopy)
        let updated = try parse(jsonString: jsonString)
        return (jsonString, appliedDefaults, updated)
    }

    static func deleteApp(in manifest: ParsedSourceManifest, at index: Int) throws -> (jsonString: String, updated: ParsedSourceManifest) {
        var rootCopy = manifest.rawRootObject
        var rawApps = (rootCopy[manifest.appsKey] as? [[String: Any]]) ?? []
        guard index >= 0 && index < rawApps.count else {
            let s = try serializePretty(rootCopy)
            return (s, try parse(jsonString: s))
        }
        rawApps.remove(at: index)
        rootCopy[manifest.appsKey] = rawApps
        let jsonString = try serializePretty(rootCopy)
        return (jsonString, try parse(jsonString: jsonString))
    }

    static func starterJSON(repoName: String, owner: String) throws -> String {
        let obj: [String: Any] = [
            "name": "\(repoName) Source",
            "identifier": "com.\(owner.lowercased()).\(repoName.lowercased())",
            "subtitle": "مصدر تطبيقات مدار بواسطة Ghost Source Manager",
            "description": "مصدر متوافق مع AltStore و LiveContainer",
            "website": "https://github.com/\(owner)/\(repoName)",
            "apps": [],
            "news": []
        ]
        return try serializePretty(obj)
    }

    static func serializePretty(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return (String(data: data, encoding: .utf8) ?? "{}") + "\n"
    }
}
