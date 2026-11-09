import Foundation

/// Public metadata for the SideSource GitHub App. The App ID is informational;
/// OAuth Device Flow requests must use the Client ID.
enum SideSourceGitHubApp {
    static let clientID = "Iv23limggee6Tl8yFl01"
    static let appID = "5674573"
    static let owner = "iosghost"
    static let deviceVerificationURL = URL(string: "https://github.com/login/device")!
}

struct GitHubDeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct GitHubDeviceTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let refreshTokenExpiresIn: Int?
    let interval: Int?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case interval
        case error
        case errorDescription = "error_description"
    }
}

private struct GitHubOAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

enum GitHubDeviceAuthError: LocalizedError {
    case invalidResponse
    case server(Int, String)
    case expired
    case denied
    case deviceFlowDisabled
    case authorization(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "استجابة تسجيل الدخول من GitHub غير صالحة. حاول بدء تسجيل الدخول مجددًا."
        case .server(let status, let detail):
            return "تعذّر الاتصال بتسجيل الدخول عبر GitHub (\(status)): \(detail)"
        case .expired:
            return "انتهت صلاحية رمز الجهاز. ابدأ تسجيل الدخول مرة أخرى للحصول على رمز جديد."
        case .denied:
            return "رُفض طلب تسجيل الدخول عبر GitHub. يمكنك المحاولة مجددًا أو استخدام التوكن اليدوي."
        case .deviceFlowDisabled:
            return "Device Flow غير مفعّل في إعدادات GitHub App. فعّله ثم أعد المحاولة."
        case .authorization(let detail):
            return "تعذّر إكمال مصادقة GitHub: \(detail)"
        }
    }
}

enum GitHubDeviceAuthService {
    private static let deviceCodeEndpoint = URL(string: "https://github.com/login/device/code")!
    private static let tokenEndpoint = URL(string: "https://github.com/login/oauth/access_token")!
    private static let deviceGrantType = "urn:ietf:params:oauth:grant-type:device_code"

    static func requestDeviceCode() async throws -> GitHubDeviceCodeResponse {
        try await postForm(
            deviceCodeEndpoint,
            parameters: [
                "client_id": SideSourceGitHubApp.clientID,
                "scope": "offline_access"
            ],
            decode: GitHubDeviceCodeResponse.self
        )
    }

    static func pollForAccessToken(
        using code: GitHubDeviceCodeResponse,
        statusUpdate: @escaping @MainActor (String) -> Void
    ) async throws -> GitHubDeviceTokenResponse {
        let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
        var interval = max(code.interval, 1)

        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            try Task.checkCancellation()

            let response = try await postForm(
                tokenEndpoint,
                parameters: [
                    "client_id": SideSourceGitHubApp.clientID,
                    "device_code": code.deviceCode,
                    "grant_type": deviceGrantType
                ],
                decode: GitHubDeviceTokenResponse.self
            )

            if let accessToken = response.accessToken, !accessToken.isEmpty {
                return response
            }

            switch response.error {
            case "authorization_pending":
                await statusUpdate("بانتظار موافقتك في GitHub…")
            case "slow_down":
                interval = max(response.interval ?? (interval + 5), interval + 5)
                await statusUpdate("يطلب GitHub إبطاء التحقق؛ ستستمر المحاولة تلقائيًا.")
            case "expired_token", "token_expired", "bad_verification_code":
                throw GitHubDeviceAuthError.expired
            case "access_denied":
                throw GitHubDeviceAuthError.denied
            case "device_flow_disabled":
                throw GitHubDeviceAuthError.deviceFlowDisabled
            case let error?:
                throw GitHubDeviceAuthError.authorization(response.errorDescription ?? error)
            case nil:
                throw GitHubDeviceAuthError.invalidResponse
            }
        }

        throw GitHubDeviceAuthError.expired
    }

    static func refreshAccessToken(using refreshToken: String) async throws -> GitHubDeviceTokenResponse {
        try await postForm(
            tokenEndpoint,
            parameters: [
                "client_id": SideSourceGitHubApp.clientID,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ],
            decode: GitHubDeviceTokenResponse.self
        )
    }

    private static func postForm<T: Decodable>(
        _ url: URL,
        parameters: [String: String],
        decode type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw GitHubDeviceAuthError.server(-1, error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubDeviceAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let oauthError = try? JSONDecoder().decode(GitHubOAuthErrorResponse.self, from: data) {
                switch oauthError.error {
                case "device_flow_disabled": throw GitHubDeviceAuthError.deviceFlowDisabled
                case "access_denied": throw GitHubDeviceAuthError.denied
                case "expired_token", "token_expired", "bad_verification_code": throw GitHubDeviceAuthError.expired
                default:
                    throw GitHubDeviceAuthError.authorization(oauthError.errorDescription ?? oauthError.error)
                }
            }
            let detail = String(data: data, encoding: .utf8) ?? "استجابة غير معروفة"
            throw GitHubDeviceAuthError.server(http.statusCode, detail)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GitHubDeviceAuthError.invalidResponse
        }
    }
}
