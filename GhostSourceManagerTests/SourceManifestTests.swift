import XCTest
@testable import GhostSourceManager

final class SourceManifestTests: XCTestCase {
    func testMissingLocalizedDescriptionDoesNotFailAndPreservesCustomFields() throws {
        let sample = """
        {
          "name": "My AltStore Source",
          "customRootKey": "keep-me",
          "apps": [
            {
              "name": "Phoenix",
              "bundleIdentifier": "com.example.phoenix",
              "version": "1.2.0",
              "downloadURL": "https://example.com/phoenix.ipa",
              "customAppField": 42,
              "versions": [{"version":"1.2.0","downloadURL":"https://example.com/phoenix.ipa","customVersionField":{"keep":true}}]
            }
          ]
        }
        """
        let doc = try SourceManifestCoder.parse(jsonString: sample)
        XCTAssertEqual(doc.apps.count, 1)
        XCTAssertFalse(doc.apps[0].hasExplicitDescription)

        let updated = try SourceManifestCoder.upsertApp(
            in: doc,
            existingIndex: 0,
            name: "Phoenix",
            bundleIdentifier: "com.example.phoenix",
            developerName: "",
            version: "1.2.0",
            buildVersion: "12",
            localizedDescription: "",
            downloadURL: "https://example.com/phoenix-1.3.0.ipa",
            iconURL: "",
            size: 48000000,
            minOSVersion: "16.0"
        )
        XCTAssertFalse(updated.appliedDefaults.isEmpty)
        XCTAssertTrue(updated.jsonString.contains("customRootKey"))
        XCTAssertTrue(updated.jsonString.contains("customAppField"))
        XCTAssertTrue(updated.jsonString.contains("customVersionField"))
        let apps = updated.updated.rawRootObject["apps"] as? [[String: Any]]
        let versions = apps?.first?["versions"] as? [[String: Any]]
        let customVersion = versions?.first?["customVersionField"] as? [String: Any]
        XCTAssertEqual(customVersion?["keep"] as? Bool, true)
    }

    func testMalformedJSONProducesHelpfulDiagnostic() {
        XCTAssertThrowsError(try SourceManifestCoder.parse(jsonString: "{\n  \"apps\": [\n")) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("JSON"))
            XCTAssertGreaterThan(message.count, 20)
        }
    }
}
