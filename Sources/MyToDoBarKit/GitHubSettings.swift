import Combine
import Foundation
import Security

public struct GitHubConfiguration: Codable, Equatable, Sendable {
    public var repositoryURL: String
    public var branch: String
    public var path: String

    public init(repositoryURL: String, branch: String = "main", path: String = "") {
        self.repositoryURL = repositoryURL
        self.branch = branch
        self.path = path
    }

    public static let defaultValue = GitHubConfiguration(
        repositoryURL: "https://github.com/Wlsflfh/TIL.git",
        branch: "main",
        path: ""
    )

    func normalized() throws -> GitHubConfiguration {
        _ = try repository
        return GitHubConfiguration(
            repositoryURL: repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines),
            branch: normalizedBranch,
            path: normalizedPath
        )
    }

    var repository: GitHubRepository {
        get throws { try GitHubRepository(urlString: repositoryURL) }
    }

    var normalizedBranch: String {
        let value = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "main" : value
    }

    var normalizedPath: String {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)
            .joined(separator: "/")
    }

    func filePath(filename: String) -> String {
        normalizedPath.isEmpty ? filename : "\(normalizedPath)/\(filename)"
    }
}

struct GitHubRepository: Equatable, Sendable {
    let owner: String
    let name: String

    init(urlString: String) throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let repositoryPath: String

        if trimmed.hasPrefix("git@github.com:") {
            repositoryPath = String(trimmed.dropFirst("git@github.com:".count))
        } else if let url = URL(string: trimmed), let scheme = url.scheme {
            guard ["http", "https"].contains(scheme.lowercased()),
                  url.host?.lowercased() == "github.com" else {
                throw GitHubPublishError.invalidRepository
            }
            repositoryPath = url.path
        } else {
            repositoryPath = trimmed
        }

        let components = repositoryPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)
        guard components.count == 2 else { throw GitHubPublishError.invalidRepository }

        let repositoryName = components[1].hasSuffix(".git")
            ? String(components[1].dropLast(4))
            : components[1]
        guard !components[0].isEmpty, !repositoryName.isEmpty else {
            throw GitHubPublishError.invalidRepository
        }
        owner = components[0]
        name = repositoryName
    }

    var identifier: String { "\(owner)/\(name)" }
}

protocol GitHubTokenStoring {
    func load() throws -> String?
    func save(_ token: String) throws
    func delete() throws
}

protocol GitHubConfigurationStoring {
    func load() -> GitHubConfiguration?
    func save(_ configuration: GitHubConfiguration)
}

struct UserDefaultsGitHubConfigurationStore: GitHubConfigurationStoring {
    let userDefaults: UserDefaults
    private let key = "github-publish-configuration"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> GitHubConfiguration? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GitHubConfiguration.self, from: data)
    }

    func save(_ configuration: GitHubConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        userDefaults.set(data, forKey: key)
    }
}

struct KeychainGitHubTokenStore: GitHubTokenStoring {
    private let service = "com.jinriro.MyToDoBar.github"
    private let account = "Wlsflfh/TIL"

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: status)
        }
        return token
    }

    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain 오류 (\(status))"
    }
}

@MainActor
public final class GitHubSettingsStore: ObservableObject {
    @Published public var tokenInput = ""
    @Published public var repositoryURLInput = ""
    @Published public var branchInput = ""
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var hasToken = false
    @Published public private(set) var configuration: GitHubConfiguration

    private let tokenStore: any GitHubTokenStoring
    private let configurationStore: any GitHubConfigurationStoring

    public convenience init() {
        self.init(
            tokenStore: KeychainGitHubTokenStore(),
            configurationStore: UserDefaultsGitHubConfigurationStore()
        )
    }

    init(
        tokenStore: any GitHubTokenStoring,
        configurationStore: any GitHubConfigurationStoring = UserDefaultsGitHubConfigurationStore()
    ) {
        self.tokenStore = tokenStore
        self.configurationStore = configurationStore
        configuration = configurationStore.load() ?? .defaultValue
        repositoryURLInput = configuration.repositoryURL
        branchInput = configuration.branch
        reloadToken()
    }

    public var token: String? {
        let trimmed = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func save() {
        guard let token else {
            statusMessage = "토큰을 입력해주세요."
            return
        }

        do {
            try tokenStore.save(token)
            tokenInput = token
            hasToken = true
            statusMessage = "GitHub 토큰을 Keychain에 저장했습니다."
        } catch {
            statusMessage = "토큰을 저장하지 못했습니다: \(error.localizedDescription)"
        }
    }

    public func saveConfiguration() {
        do {
            let updated = try GitHubConfiguration(
                repositoryURL: repositoryURLInput,
                branch: branchInput,
                path: ""
            ).normalized()
            configurationStore.save(updated)
            configuration = updated
            repositoryURLInput = updated.repositoryURL
            branchInput = updated.branch
            statusMessage = "GitHub 게시 설정을 저장했습니다."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func clear() {
        do {
            try tokenStore.delete()
            tokenInput = ""
            hasToken = false
            statusMessage = "저장된 GitHub 토큰을 삭제했습니다."
        } catch {
            statusMessage = "토큰을 삭제하지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func reloadToken() {
        do {
            tokenInput = try tokenStore.load() ?? ""
            hasToken = !tokenInput.isEmpty
            statusMessage = nil
        } catch {
            statusMessage = "Keychain에서 토큰을 읽지 못했습니다: \(error.localizedDescription)"
        }
    }
}
