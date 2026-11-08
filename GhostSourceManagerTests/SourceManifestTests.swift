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
              "customAppField": 42
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
            version: "1.3.0",
            buildVersion: "13",
            localizedDescription: "",
            downloadURL: "https://example.com/phoenix-1.3.0.ipa",
            iconURL: "",
            size: 48000000,
            minOSVersion: "16.0"
        )
        XCTAssertFalse(updated.appliedDefaults.isEmpty)
        XCTAssertTrue(updated.jsonString.contains("customRootKey"))
        XCTAssertTrue(updated.jsonString.contains("customAppField"))
    }
}
