import Foundation

struct GitHubUser: Codable, Equatable {
    let login: String
    let name: String?
    let avatarUrl: String
    let htmlUrl: String
    let publicRepos: Int?

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case publicRepos = "public_repos"
    }
}

struct GitHubRepoOwner: Codable, Equatable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String?
    let defaultBranch: String
    let updatedAt: String
    let htmlUrl: String
    let owner: GitHubRepoOwner

    enum CodingKeys: String, CodingKey {
        case id, name, description, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }
}

struct GitHubBranch: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
}

struct GitHubTreeResponse: Codable {
    struct Entry: Codable {
        let path: String
        let type: String
        let sha: String
    }
    let tree: [Entry]
}

struct GitHubContentFile: Codable {
    let path: String
    let sha: String
    let content: String?
    let encoding: String?
    let downloadUrl: String?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case path, sha, content, encoding
        case downloadUrl = "download_url"
        case htmlUrl = "html_url"
    }
}

struct GitHubReleaseAsset: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let size: Int64
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

struct GitHubRelease: Codable, Identifiable, Equatable {
    let id: Int
    let tagName: String
    let name: String?
    let htmlUrl: String
    let uploadUrl: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id, name, assets
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case uploadUrl = "upload_url"
    }
}
