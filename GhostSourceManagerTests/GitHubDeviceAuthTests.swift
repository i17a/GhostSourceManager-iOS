import XCTest
@testable import GhostSourceManager

final class GitHubDeviceAuthTests: XCTestCase {
    func testDeviceCodeResponseDecodesUserCodeAndPollingInterval() throws {
        let json = #"{"device_code":"device-secret-for-test","user_code":"WDJB-MJHT","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#
        let code = try JSONDecoder().decode(GitHubDeviceCodeResponse.self, from: Data(json.utf8))

        XCTAssertEqual(code.userCode, "WDJB-MJHT")
        XCTAssertEqual(code.verificationURI.absoluteString, "https://github.com/login/device")
        XCTAssertEqual(code.expiresIn, 900)
        XCTAssertEqual(code.interval, 5)
    }

    func testDeviceTokenResponseDecodesAccessAndRotatingRefreshTokens() throws {
        let json = #"{"access_token":"ghu_access-test","refresh_token":"ghr_refresh-test","expires_in":28800,"refresh_token_expires_in":15897600,"token_type":"bearer","scope":""}"#
        let token = try JSONDecoder().decode(GitHubDeviceTokenResponse.self, from: Data(json.utf8))

        XCTAssertEqual(token.accessToken, "ghu_access-test")
        XCTAssertEqual(token.refreshToken, "ghr_refresh-test")
        XCTAssertEqual(token.expiresIn, 28800)
        XCTAssertEqual(token.refreshTokenExpiresIn, 15897600)
        XCTAssertNil(token.error)
    }

    func testDeviceFlowErrorResponseDecodesAuthorizationPending() throws {
        let json = #"{"error":"authorization_pending","error_description":"The user has not yet authorized the device."}"#
        let response = try JSONDecoder().decode(GitHubDeviceTokenResponse.self, from: Data(json.utf8))

        XCTAssertNil(response.accessToken)
        XCTAssertEqual(response.error, "authorization_pending")
    }
}
