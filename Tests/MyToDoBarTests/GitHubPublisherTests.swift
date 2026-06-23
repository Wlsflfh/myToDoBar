import Foundation
import XCTest
@testable import MyToDoBarKit

final class GitHubPublisherTests: XCTestCase {
    func testBuildsMarkdownWithFrontMatterAndSanitizedFilename() throws {
        let note = DailyNote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: Date(timeIntervalSince1970: 0),
            title: " Swift/Concurrency ",
            text: "내용"
        )

        XCTAssertEqual(try GitHubPublisher.filename(for: note.title), "Swift-Concurrency.md")
        let markdown = GitHubPublisher.markdown(for: note)
        XCTAssertTrue(markdown.contains("id: \"00000000-0000-0000-0000-000000000001\""))
        XCTAssertTrue(markdown.contains("title: \" Swift/Concurrency \""))
        XCTAssertTrue(markdown.hasSuffix("\n내용"))
    }

    func testCreatesNumberedFileWhenTitleAlreadyExists() async throws {
        let api = FakeGitHubContentAPI(files: ["contents/회의.md": "existing"])
        let publisher = GitHubPublisher(api: api)

        let result = try await publisher.publish(
            note: DailyNote(date: Date(), title: "회의"),
            token: "token",
            configuration: contentsConfiguration
        )
        let paths = await api.paths

        XCTAssertEqual(result.path, "contents/회의-2.md")
        XCTAssertEqual(paths, ["contents/회의-2.md", "contents/회의.md"])
    }

    func testUpdatesSameMemoUsingLastKnownSHA() async throws {
        let api = FakeGitHubContentAPI(files: ["contents/회의.md": "sha-1"])
        let publisher = GitHubPublisher(api: api)
        let note = DailyNote(
            date: Date(),
            title: "회의",
            text: "변경",
            remotePath: "contents/회의.md",
            remoteSHA: "sha-1"
        )

        let result = try await publisher.publish(
            note: note,
            token: "token",
            configuration: contentsConfiguration
        )
        let operations = await api.operations

        XCTAssertEqual(result.path, "contents/회의.md")
        XCTAssertEqual(operations, [.put("contents/회의.md", "sha-1")])
    }

    func testRejectsUpdateWhenRemoteSHAChanged() async throws {
        let api = FakeGitHubContentAPI(files: ["contents/회의.md": "remote-change"])
        let publisher = GitHubPublisher(api: api)
        let note = DailyNote(
            date: Date(),
            title: "회의",
            remotePath: "contents/회의.md",
            remoteSHA: "sha-1"
        )

        do {
            _ = try await publisher.publish(
                note: note,
                token: "token",
                configuration: contentsConfiguration
            )
            XCTFail("Expected a remote change conflict")
        } catch let error as GitHubPublishError {
            XCTAssertEqual(error, .remoteChanged)
        }
        let operations = await api.operations
        XCTAssertEqual(operations, [])
    }

    func testRenamesExistingMemoSerially() async throws {
        let api = FakeGitHubContentAPI(files: ["contents/이전 제목.md": "sha-1"])
        let publisher = GitHubPublisher(api: api)
        let note = DailyNote(
            date: Date(),
            title: "새 제목",
            remotePath: "contents/이전 제목.md",
            remoteSHA: "sha-1"
        )

        let result = try await publisher.publish(
            note: note,
            token: "token",
            configuration: contentsConfiguration
        )
        let operations = await api.operations
        let paths = await api.paths

        XCTAssertEqual(result.path, "contents/새 제목.md")
        XCTAssertEqual(
            operations,
            [.put("contents/새 제목.md", nil), .delete("contents/이전 제목.md", "sha-1")]
        )
        XCTAssertEqual(paths, ["contents/새 제목.md"])
    }

    func testUsesConfiguredRepositoryBranchAndRootPath() async throws {
        let api = FakeGitHubContentAPI()
        let publisher = GitHubPublisher(api: api)
        let configuration = GitHubConfiguration(
            repositoryURL: "https://github.com/example/notes.git",
            branch: "",
            path: ""
        )

        let result = try await publisher.publish(
            note: DailyNote(date: Date(), title: "Swift"),
            token: "token",
            configuration: configuration
        )
        let targets = await api.targets

        XCTAssertEqual(result.path, "Swift.md")
        XCTAssertEqual(result.repository, "example/notes")
        XCTAssertEqual(result.branch, "main")
        XCTAssertEqual(targets, ["example/notes@main", "example/notes@main"])
    }

    private var contentsConfiguration: GitHubConfiguration {
        GitHubConfiguration(
            repositoryURL: "https://github.com/Wlsflfh/TIL.git",
            branch: "main",
            path: "contents"
        )
    }
}

private actor FakeGitHubContentAPI: GitHubContentAPI {
    enum Operation: Equatable, Sendable {
        case put(String, String?)
        case delete(String, String)
    }

    private var files: [String: String]
    private(set) var operations: [Operation] = []
    private(set) var targets: [String] = []
    private var nextSHA = 2

    init(files: [String: String] = [:]) {
        self.files = files
    }

    var paths: [String] { files.keys.sorted() }

    func file(
        path: String,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> GitHubRemoteFile? {
        targets.append(try target(for: configuration))
        return files[path].map { GitHubRemoteFile(path: path, sha: $0) }
    }

    func put(
        path: String,
        content: String,
        sha: String?,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> GitHubRemoteFile {
        targets.append(try target(for: configuration))
        operations.append(.put(path, sha))
        let newSHA = "sha-\(nextSHA)"
        nextSHA += 1
        files[path] = newSHA
        return GitHubRemoteFile(path: path, sha: newSHA)
    }

    func delete(
        path: String,
        sha: String,
        configuration: GitHubConfiguration,
        token: String
    ) async throws {
        targets.append(try target(for: configuration))
        operations.append(.delete(path, sha))
        files.removeValue(forKey: path)
    }

    private func target(for configuration: GitHubConfiguration) throws -> String {
        let repository = try configuration.repository
        return "\(repository.identifier)@\(configuration.branch)"
    }
}
