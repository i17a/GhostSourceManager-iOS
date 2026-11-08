import Foundation
import SwiftUI

enum MainTab: Int, CaseIterable {
    case home = 0
    case sources = 1
    case addIPA = 2
    case apps = 3
    case reports = 4
}

struct ActivityReportEntry: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
    let isSuccess: Bool
    let urlString: String?
}

@MainActor
final class SourceManagerViewModel: ObservableObject {
    @Published var selectedTab: MainTab = .sources
    @Published var showLoginSheet: Bool = false

    @Published private(set) var currentUser: GitHubUser?
    @Published private(set) var grantedScopes: [String] = []
    @Published var isAuthenticating: Bool = false
    @Published var authError: String?

    @Published var repositories: [GitHubRepo] = []
    @Published var isLoadingRepos: Bool = false
    @Published var selectedRepo: GitHubRepo?
    @Published var branches: [GitHubBranch] = []
    @Published var selectedBranch: String = "main"
    @Published var candidateFiles: [String] = ["apps.json"]
    @Published var selectedFilePath: String = "apps.json"

    @Published var currentFileSha: String?
    @Published var rawJSONString: String = ""
    @Published var manifest: ParsedSourceManifest?
    @Published var missingSourceFilePrompt: Bool = false
    @Published var isLoadingSource: Bool = false
    @Published var sourceError: String?

    @Published var editingApp: SourceAppItem?
    @Published var activityLogs: [ActivityReportEntry] = []

    private let api = GitHubAPIService()
    private let lastRepoKey = "ghost_last_repo_fullname"
    private let lastBranchKey = "ghost_last_branch"
    private let lastPathKey = "ghost_last_filepath"

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-manifest") {
            let fixture = """
            {"name":"UI Test Source","customRoot":"preserved","apps":[{"name":"Fixture App","bundleIdentifier":"test.fixture.app","version":"1.0","customAppField":42}]}
            """
            rawJSONString = fixture
            currentFileSha = "ui-test-sha"
            manifest = try? SourceManifestCoder.parse(jsonString: fixture)
            return
        }
#endif
        if let savedToken = KeychainService.readToken(), !savedToken.isEmpty {
            Task {
                await authenticate(with: savedToken, saveToKeychain: false)
            }
        }
    }

    var activeToken: String? {
        KeychainService.readToken()
    }

    var rawSourceURLString: String? {
        guard let repo = selectedRepo else { return nil }
        return GitHubAPIService.rawGitHubURL(fullName: repo.fullName, branch: selectedBranch, path: selectedFilePath)
    }

    func log(_ title: String, detail: String, isSuccess: Bool, url: String? = nil) {
        activityLogs.insert(
            ActivityReportEntry(date: Date(), title: title, detail: detail, isSuccess: isSuccess, urlString: url),
            at: 0
        )
    }

    func authenticate(with rawToken: String, saveToKeychain: Bool = true) async {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            authError = "يرجى إدخال GitHub Personal Access Token."
            return
        }
        isAuthenticating = true
        authError = nil
        do {
            let result = try await api.verifyToken(trimmed)
            if saveToKeychain {
                try KeychainService.saveToken(trimmed)
            }
            currentUser = result.user
            grantedScopes = result.scopes
            showLoginSheet = false
            log("تم تسجيل الدخول", detail: "متصل بحساب @\(result.user.login)", isSuccess: true)
            await refreshRepositories()
        } catch {
            authError = error.localizedDescription
            if !saveToKeychain {
                KeychainService.deleteToken()
            }
        }
        isAuthenticating = false
    }

    func signOut() {
        KeychainService.deleteToken()
        currentUser = nil
        grantedScopes = []
        repositories = []
        selectedRepo = nil
        manifest = nil
        rawJSONString = ""
        currentFileSha = nil
        log("تسجيل الخروج", detail: "تم حذف التوكن من iOS Keychain", isSuccess: true)
    }

    func refreshRepositories() async {
        guard let token = activeToken else { return }
        isLoadingRepos = true
        do {
            let list = try await api.listRepositories(token: token)
            repositories = list
            if selectedRepo == nil,
               let savedFull = UserDefaults.standard.string(forKey: lastRepoKey),
               let matched = list.first(where: { $0.fullName == savedFull }) {
                let savedBr = UserDefaults.standard.string(forKey: lastBranchKey)
                let savedPath = UserDefaults.standard.string(forKey: lastPathKey)
                await selectRepository(matched, preferredBranch: savedBr, preferredPath: savedPath)
            }
        } catch {
            sourceError = error.localizedDescription
        }
        isLoadingRepos = false
    }

    func selectRepository(_ repo: GitHubRepo, preferredBranch: String? = nil, preferredPath: String? = nil) async {
        guard let token = activeToken else { return }
        selectedRepo = repo
        let branch = preferredBranch ?? repo.defaultBranch
        selectedBranch = branch
        sourceError = nil
        missingSourceFilePrompt = false

        do {
            async let brTask = api.listBranches(token: token, fullName: repo.fullName)
            async let filesTask = api.listCandidateJSONFiles(token: token, fullName: repo.fullName, branch: branch)
            let (fetchedBranches, jsonCandidates) = try await (brTask, filesTask)
            branches = fetchedBranches
            candidateFiles = jsonCandidates
            let path = preferredPath ?? jsonCandidates.first ?? "apps.json"
            selectedFilePath = path
            await loadSelectedSourceFile()
        } catch {
            sourceError = error.localizedDescription
        }
    }

    func changeBranch(_ newBranch: String) async {
        guard let token = activeToken, let repo = selectedRepo else { return }
        selectedBranch = newBranch
        candidateFiles = await api.listCandidateJSONFiles(token: token, fullName: repo.fullName, branch: newBranch)
        if let first = candidateFiles.first {
            selectedFilePath = first
        }
        await loadSelectedSourceFile()
    }

    func loadSelectedSourceFile() async {
        guard let token = activeToken, let repo = selectedRepo else { return }
        isLoadingSource = true
        sourceError = nil
        missingSourceFilePrompt = false
        do {
            let file = try await api.fetchFile(token: token, fullName: repo.fullName, path: selectedFilePath, branch: selectedBranch)
            currentFileSha = file.sha
            rawJSONString = file.content
            manifest = try SourceManifestCoder.parse(jsonString: file.content)
            UserDefaults.standard.set(repo.fullName, forKey: lastRepoKey)
            UserDefaults.standard.set(selectedBranch, forKey: lastBranchKey)
            UserDefaults.standard.set(selectedFilePath, forKey: lastPathKey)
            log("تحميل السورس", detail: "\(repo.fullName)/\(selectedFilePath)", isSuccess: true)
        } catch GitHubServiceError.notFound {
            currentFileSha = nil
            manifest = nil
            missingSourceFilePrompt = true
        } catch {
            currentFileSha = nil
            manifest = nil
            sourceError = error.localizedDescription
        }
        isLoadingSource = false
    }

    func createNewStarterSourceFile() async {
        guard let token = activeToken, let repo = selectedRepo else { return }
        isLoadingSource = true
        sourceError = nil
        do {
            let starter = try SourceManifestCoder.starterJSON(repoName: repo.name, owner: repo.owner.login)
            let res = try await api.putFile(
                token: token,
                fullName: repo.fullName,
                path: selectedFilePath,
                branch: selectedBranch,
                data: Data(starter.utf8),
                message: "Initialize \(selectedFilePath) via Ghost Source Manager",
                sha: nil
            )
            currentFileSha = res.newSha
            rawJSONString = starter
            manifest = try SourceManifestCoder.parse(jsonString: starter)
            missingSourceFilePrompt = false
            log("إنشاء ملف سورس جديد", detail: selectedFilePath, isSuccess: true, url: res.htmlURL)
        } catch {
            sourceError = error.localizedDescription
        }
        isLoadingSource = false
    }

    func saveRawJSON(_ jsonText: String, commitMessage: String) async throws {
        guard let token = activeToken, let repo = selectedRepo else {
            throw GitHubServiceError.unauthorized
        }
        let parsed = try SourceManifestCoder.parse(jsonString: jsonText)
        let expectedSHA = currentFileSha
        do {
            let latest = try await api.fetchFile(
                token: token,
                fullName: repo.fullName,
                path: selectedFilePath,
                branch: selectedBranch
            )
            guard latest.sha == expectedSHA else {
                await loadSelectedSourceFile()
                throw GitHubServiceError.shaConflict("تغيّر الملف على GitHub منذ تحميله. حُفظت مسودتك الحالية؛ راجع النسخة الأحدث قبل إعادة المحاولة.")
            }
        } catch GitHubServiceError.notFound {
            guard expectedSHA == nil else {
                await loadSelectedSourceFile()
                throw GitHubServiceError.shaConflict("لم يعد الملف الموجود سابقاً موجوداً على GitHub. حُفظت مسودتك الحالية للمراجعة.")
            }
        }
        do {
            let res = try await api.putFile(
                token: token,
                fullName: repo.fullName,
                path: selectedFilePath,
                branch: selectedBranch,
                data: Data(jsonText.utf8),
                message: commitMessage,
                sha: expectedSHA
            )
            currentFileSha = res.newSha
            rawJSONString = jsonText
            manifest = parsed
            log("تحديث ملف السورس", detail: commitMessage, isSuccess: true, url: res.htmlURL)
        } catch GitHubServiceError.shaConflict {
            await loadSelectedSourceFile()
            throw GitHubServiceError.shaConflict("تم رصد تعديل خارجي أحدث على الملف؛ أعدنا تحميل النسخة الحالية للمراجعة بأمان.")
        }
    }

    func deleteApp(_ app: SourceAppItem) async throws {
        guard let current = manifest else { return }
        let (jsonString, _) = try SourceManifestCoder.deleteApp(in: current, at: app.index)
        try await saveRawJSON(jsonString, commitMessage: "Remove \(app.name) from \(selectedFilePath)")
    }

    func checkReleaseAssetExists(tagName: String, assetName: String) async -> Bool {
        guard let token = activeToken, let repo = selectedRepo else { return false }
        guard let rel = try? await api.getOrCreateRelease(
            token: token,
            fullName: repo.fullName,
            tagName: tagName,
            releaseName: tagName,
            targetBranch: selectedBranch,
            notes: tagName
        ) else { return false }
        return rel.assets.contains(where: { $0.name == assetName })
    }

    struct PublishOutcome {
        let releaseURL: String?
        let sourceRawURL: String?
        let appliedDefaults: [String]
        let partialFailureWarning: String?
    }

    func publishIPAAndUpdateSource(
        existingIndex: Int?,
        name: String,
        bundleID: String,
        developerName: String,
        version: String,
        buildVersion: String,
        localizedDescription: String,
        manualDownloadURL: String,
        manualIconURL: String,
        fileSize: Int64,
        minOSVersion: String?,
        tagName: String,
        uploadToRelease: Bool,
        updateManifest: Bool,
        analyzedIPA: AnalyzedIPA?,
        replaceExistingAsset: Bool,
        onStepUpdate: @escaping (String) -> Void
    ) async throws -> PublishOutcome {
        guard let token = activeToken, let repo = selectedRepo else {
            throw GitHubServiceError.unauthorized
        }

        var finalDownloadURL = manualDownloadURL
        var finalIconURL = manualIconURL
        var releaseHTMLURL: String?

        if uploadToRelease, let ipa = analyzedIPA {
            onStepUpdate("جارِ إنشاء/فحص GitHub Release ورفع ملف الـ IPA...")
            let release = try await api.getOrCreateRelease(
                token: token,
                fullName: repo.fullName,
                tagName: tagName,
                releaseName: "\(name) \(version)",
                targetBranch: selectedBranch,
                notes: localizedDescription.isEmpty ? "\(name) v\(version)" : localizedDescription
            )
            releaseHTMLURL = release.htmlUrl

            if let existing = release.assets.first(where: { $0.name == ipa.fileName }) {
                if replaceExistingAsset {
                    try await api.deleteReleaseAsset(token: token, fullName: repo.fullName, assetID: existing.id)
                    let uploaded = try await api.uploadReleaseAsset(
                        token: token,
                        fullName: repo.fullName,
                        releaseID: release.id,
                        fileName: ipa.fileName,
                        fileURL: ipa.fileURL
                    )
                    finalDownloadURL = uploaded.browserDownloadUrl
                } else {
                    finalDownloadURL = existing.browserDownloadUrl
                }
            } else {
                let uploaded = try await api.uploadReleaseAsset(
                    token: token,
                    fullName: repo.fullName,
                    releaseID: release.id,
                    fileName: ipa.fileName,
                    fileURL: ipa.fileURL
                )
                finalDownloadURL = uploaded.browserDownloadUrl
            }
        }

        if updateManifest, let iconData = analyzedIPA?.iconPNGData {
            onStepUpdate("جارِ رفع أيقونة التطبيق إلى المستودع...")
            let safeBundle = bundleID.replacingOccurrences(of: "/", with: "_")
            let iconPath = "icons/\(safeBundle).png"
            let existingIconSha = (try? await api.fetchFile(token: token, fullName: repo.fullName, path: iconPath, branch: selectedBranch))?.sha
            if let _ = try? await api.putFile(
                token: token,
                fullName: repo.fullName,
                path: iconPath,
                branch: selectedBranch,
                data: iconData,
                message: "Upload icon for \(name)",
                sha: existingIconSha
            ) {
                finalIconURL = GitHubAPIService.rawGitHubURL(fullName: repo.fullName, branch: selectedBranch, path: iconPath)
            }
        }

        var appliedDefaults: [String] = []
        if updateManifest {
            onStepUpdate("جارِ تحديث ملف السورس وحفظه في الفرع \(selectedBranch)...")
            do {
                let baseManifest: ParsedSourceManifest
                if let current = manifest {
                    baseManifest = current
                } else {
                    let starter = try SourceManifestCoder.starterJSON(repoName: repo.name, owner: repo.owner.login)
                    baseManifest = try SourceManifestCoder.parse(jsonString: starter)
                }

                let upserted = try SourceManifestCoder.upsertApp(
                    in: baseManifest,
                    existingIndex: existingIndex,
                    name: name,
                    bundleIdentifier: bundleID,
                    developerName: developerName,
                    version: version,
                    buildVersion: buildVersion,
                    localizedDescription: localizedDescription,
                    downloadURL: finalDownloadURL,
                    iconURL: finalIconURL,
                    size: fileSize,
                    minOSVersion: minOSVersion
                )
                appliedDefaults = upserted.appliedDefaults
                try await saveRawJSON(
                    upserted.jsonString,
                    commitMessage: "Publish \(name) v\(version) via Ghost Source Manager"
                )
            } catch {
                if uploadToRelease && !finalDownloadURL.isEmpty {
                    let partialMsg = "رُفع ملف IPA إلى Release بنجاح، لكن فشل تحديث ملف السورس: \(error.localizedDescription)"
                    log("نجاح جزئي", detail: partialMsg, isSuccess: false, url: releaseHTMLURL)
                    return PublishOutcome(
                        releaseURL: releaseHTMLURL,
                        sourceRawURL: nil,
                        appliedDefaults: appliedDefaults,
                        partialFailureWarning: partialMsg
                    )
                }
                throw error
            }
        }

        onStepUpdate("اكتمل الرفع والنشر بنجاح!")
        return PublishOutcome(
            releaseURL: releaseHTMLURL,
            sourceRawURL: rawSourceURLString,
            appliedDefaults: appliedDefaults,
            partialFailureWarning: nil
        )
    }
}
