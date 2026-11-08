import Foundation

enum GitHubServiceError: LocalizedError {
    case unauthorized
    case forbidden(String)
    case notFound
    case shaConflict(String)
    case networkFailure
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "التوكن غير صالح أو منتهي الصلاحية (401)."
        case .forbidden(let detail):
            return "صلاحيات التوكن غير كافية أو تم تجاوز حد الطلبات: \(detail)"
        case .notFound:
            return "الملف أو المستودع غير موجود (404)."
        case .shaConflict(let detail):
            return "تعارض في نسخة الملف (SHA تغيّر على GitHub): \(detail)"
        case .networkFailure:
            return "تعذّر الاتصال بـ GitHub. تحقق من اتصال الإنترنت."
        case .serverError(let code, let detail):
            return "خطأ من GitHub (\(code)): \(detail)"
        }
    }
}

final class GitHubAPIService {
    private let baseURL = URL(string: "https://api.github.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func authorizedRequest(url: URL, token: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> (T, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubServiceError.networkFailure
        }
        guard let http = response as? HTTPURLResponse else {
            throw GitHubServiceError.networkFailure
        }
        try validateStatus(http.statusCode, data: data)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return (decoded, http)
    }

    private func validateStatus(_ status: Int, data: Data) throws {
        guard !(200...299).contains(status) else { return }
        let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? ""
        switch status {
        case 401: throw GitHubServiceError.unauthorized
        case 403: throw GitHubServiceError.forbidden(msg)
        case 404: throw GitHubServiceError.notFound
        case 409, 422: throw GitHubServiceError.shaConflict(msg)
        default: throw GitHubServiceError.serverError(status, msg)
        }
    }

    func verifyToken(_ token: String) async throws -> (user: GitHubUser, scopes: [String]) {
        let req = authorizedRequest(url: baseURL.appendingPathComponent("user"), token: token)
        let (user, http): (GitHubUser, HTTPURLResponse) = try await perform(req)
        let scopeHeader = http.value(forHTTPHeaderField: "X-OAuth-Scopes") ?? ""
        let scopes = scopeHeader.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return (user, scopes)
    }

    func listRepositories(token: String) async throws -> [GitHubRepo] {
        var all: [GitHubRepo] = []
        for page in 1...3 {
            var comps = URLComponents(url: baseURL.appendingPathComponent("user/repos"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")
            ]
            let req = authorizedRequest(url: comps.url!, token: token)
            let (batch, _): ([GitHubRepo], HTTPURLResponse) = try await perform(req)
            all.append(contentsOf: batch)
            if batch.count < 100 { break }
        }
        return all
    }

    func listBranches(token: String, fullName: String) async throws -> [GitHubBranch] {
        let url = URL(string: "https://api.github.com/repos/\(fullName)/branches?per_page=100")!
        let req = authorizedRequest(url: url, token: token)
        let (branches, _): ([GitHubBranch], HTTPURLResponse) = try await perform(req)
        return branches
    }

    func listCandidateJSONFiles(token: String, fullName: String, branch: String) async -> [String] {
        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? branch
        guard let url = URL(string: "https://api.github.com/repos/\(fullName)/git/trees/\(encodedBranch)?recursive=1") else {
            return ["apps.json"]
        }
        let req = authorizedRequest(url: url, token: token)
        guard let (tree, _): (GitHubTreeResponse, HTTPURLResponse) = try? await perform(req) else {
            return ["apps.json"]
        }
        let priority = ["apps.json", "source.json", "altstore.json", "repo.json", "manifest.json"]
        let files = tree.tree
            .filter { $0.type == "blob" && $0.path.lowercased().hasSuffix(".json") && !$0.path.hasPrefix(".") }
            .map(\.path)
            .sorted { a, b in
                let aName = (a as NSString).lastPathComponent.lowercased()
                let bName = (b as NSString).lastPathComponent.lowercased()
                let ai = priority.firstIndex(of: aName) ?? Int.max
                let bi = priority.firstIndex(of: bName) ?? Int.max
                return ai == bi ? a < b : ai < bi
            }
        return files.isEmpty ? ["apps.json"] : files
    }

    func fetchFile(token: String, fullName: String, path: String, branch: String) async throws -> (content: String, sha: String, htmlURL: String) {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var comps = URLComponents(string: "https://api.github.com/repos/\(fullName)/contents/\(cleanPath)")!
        comps.queryItems = [URLQueryItem(name: "ref", value: branch)]
        let req = authorizedRequest(url: comps.url!, token: token)
        let (file, _): (GitHubContentFile, HTTPURLResponse) = try await perform(req)

        if let b64 = file.content {
            let sanitized = b64.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
            if let data = Data(base64Encoded: sanitized), let str = String(data: data, encoding: .utf8) {
                return (str, file.sha, file.htmlUrl)
            }
        }
        if let raw = file.downloadUrl, let rawURL = URL(string: raw) {
            let (rawData, _) = try await session.data(from: rawURL)
            if let str = String(data: rawData, encoding: .utf8) {
                return (str, file.sha, file.htmlUrl)
            }
        }
        return ("", file.sha, file.htmlUrl)
    }

    func putFile(
        token: String,
        fullName: String,
        path: String,
        branch: String,
        data: Data,
        message: String,
        sha: String?
    ) async throws -> (newSha: String, htmlURL: String) {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "https://api.github.com/repos/\(fullName)/contents/\(cleanPath)")!
        var req = authorizedRequest(url: url, token: token, method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "message": message,
            "content": data.base64EncodedString(),
            "branch": branch
        ]
        if let sha { body["sha"] = sha }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        struct PutResponse: Codable {
            struct ContentInfo: Codable {
                let sha: String
                let html_url: String
            }
            let content: ContentInfo
        }
        let (res, _): (PutResponse, HTTPURLResponse) = try await perform(req)
        return (res.content.sha, res.content.html_url)
    }

    func getOrCreateRelease(
        token: String,
        fullName: String,
        tagName: String,
        releaseName: String,
        targetBranch: String,
        notes: String
    ) async throws -> GitHubRelease {
        let encodedTag = tagName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tagName
        let getURL = URL(string: "https://api.github.com/repos/\(fullName)/releases/tags/\(encodedTag)")!
        do {
            let (existing, _): (GitHubRelease, HTTPURLResponse) = try await perform(authorizedRequest(url: getURL, token: token))
            return existing
        } catch GitHubServiceError.notFound {
            let createURL = URL(string: "https://api.github.com/repos/\(fullName)/releases")!
            var req = authorizedRequest(url: createURL, token: token, method: "POST")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "tag_name": tagName,
                "target_commitish": targetBranch,
                "name": releaseName,
                "body": notes,
                "draft": false,
                "prerelease": false
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (created, _): (GitHubRelease, HTTPURLResponse) = try await perform(req)
            return created
        }
    }

    func deleteReleaseAsset(token: String, fullName: String, assetID: Int) async throws {
        let url = URL(string: "https://api.github.com/repos/\(fullName)/releases/assets/\(assetID)")!
        let req = authorizedRequest(url: url, token: token, method: "DELETE")
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            try validateStatus(http.statusCode, data: Data())
        }
    }

    func uploadReleaseAsset(
        token: String,
        fullName: String,
        releaseID: Int,
        fileName: String,
        fileURL: URL
    ) async throws -> GitHubReleaseAsset {
        var comps = URLComponents(string: "https://uploads.github.com/repos/\(fullName)/releases/\(releaseID)/assets")!
        comps.queryItems = [URLQueryItem(name: "name", value: fileName)]
        var req = authorizedRequest(url: comps.url!, token: token, method: "POST")
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: req, fromFile: fileURL)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubServiceError.networkFailure
        }
        try validateStatus(http.statusCode, data: data)
        return try JSONDecoder().decode(GitHubReleaseAsset.self, from: data)
    }

    static func rawGitHubURL(fullName: String, branch: String, path: String) -> String {
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "https://raw.githubusercontent.com/\(fullName)/\(branch)/\(clean)"
    }
}
