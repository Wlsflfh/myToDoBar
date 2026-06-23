import XCTest
@testable import MyToDoBarKit

final class GitHubSettingsTests: XCTestCase {
    @MainActor
    func testLoadsAndSavesTokenThroughSecureStore() {
        let tokenStore = FakeGitHubTokenStore(token: "existing")
        let settings = GitHubSettingsStore(tokenStore: tokenStore)

        XCTAssertEqual(settings.token, "existing")
        XCTAssertTrue(settings.hasToken)

        settings.tokenInput = "  replacement  "
        settings.save()

        XCTAssertEqual(tokenStore.token, "replacement")
        XCTAssertEqual(settings.token, "replacement")
        XCTAssertTrue(settings.hasToken)
    }

    @MainActor
    func testClearsToken() {
        let tokenStore = FakeGitHubTokenStore(token: "existing")
        let settings = GitHubSettingsStore(tokenStore: tokenStore)

        settings.clear()

        XCTAssertNil(tokenStore.token)
        XCTAssertNil(settings.token)
        XCTAssertFalse(settings.hasToken)
    }

    @MainActor
    func testSavesAndReloadsNormalizedPublishConfiguration() {
        let configurationStore = FakeGitHubConfigurationStore()
        let settings = GitHubSettingsStore(
            tokenStore: FakeGitHubTokenStore(),
            configurationStore: configurationStore
        )
        settings.repositoryURLInput = " https://github.com/example/notes.git "
        settings.branchInput = " "

        settings.saveConfiguration()

        XCTAssertEqual(settings.configuration.repositoryURL, "https://github.com/example/notes.git")
        XCTAssertEqual(settings.configuration.branch, "main")
        XCTAssertEqual(settings.configuration.path, "")

        let restored = GitHubSettingsStore(
            tokenStore: FakeGitHubTokenStore(),
            configurationStore: configurationStore
        )
        XCTAssertEqual(restored.configuration, settings.configuration)
    }
}

private final class FakeGitHubTokenStore: GitHubTokenStoring {
    var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func load() throws -> String? { token }
    func save(_ token: String) throws { self.token = token }
    func delete() throws { token = nil }
}

private final class FakeGitHubConfigurationStore: GitHubConfigurationStoring {
    var configuration: GitHubConfiguration?

    func load() -> GitHubConfiguration? { configuration }
    func save(_ configuration: GitHubConfiguration) { self.configuration = configuration }
}
