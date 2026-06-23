import Foundation

public struct GitHubPublishResult: Equatable, Sendable {
    public let path: String
    public let sha: String
    public let repository: String
    public let branch: String
}

public enum GitHubPublishError: LocalizedError, Equatable, Sendable {
    case missingToken
    case emptyTitle
    case invalidRepository
    case remoteChanged
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "설정에서 GitHub 토큰을 먼저 저장해주세요."
        case .emptyTitle:
            "메모 제목을 입력해주세요."
        case .invalidRepository:
            "GitHub 저장소 URL을 확인해주세요."
        case .remoteChanged:
            "GitHub에서 이 파일이 변경되었습니다. 원격 내용을 확인해주세요."
        case .requestFailed(let message):
            "GitHub 업로드에 실패했습니다: \(message)"
        }
    }
}

struct GitHubRemoteFile: Equatable, Sendable {
    let path: String
    let sha: String
}

protocol GitHubContentAPI: Sendable {
    func file(path: String, configuration: GitHubConfiguration, token: String) async throws -> GitHubRemoteFile?
    func put(
        path: String,
        content: String,
        sha: String?,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> GitHubRemoteFile
    func delete(path: String, sha: String, configuration: GitHubConfiguration, token: String) async throws
}

public struct GitHubPublisher: Sendable {
    private let api: any GitHubContentAPI

    public init() {
        self.api = GitHubRESTContentAPI()
    }

    init(api: any GitHubContentAPI) {
        self.api = api
    }

    public func publish(
        note: DailyNote,
        token: String,
        configuration: GitHubConfiguration = .defaultValue
    ) async throws -> GitHubPublishResult {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw GitHubPublishError.missingToken }
        let configuration = try configuration.normalized()
        let repository = try configuration.repository

        let filename = try Self.filename(for: note.title)
        let desiredPath = configuration.filePath(filename: filename)
        let content = Self.markdown(for: note)
        let remoteRepository = note.remoteRepository ?? "Wlsflfh/TIL"
        let remoteBranch = note.remoteBranch ?? "main"
        let isSameRemote = remoteRepository.caseInsensitiveCompare(repository.identifier) == .orderedSame
            && remoteBranch == configuration.branch

        guard isSameRemote, let remotePath = note.remotePath, let remoteSHA = note.remoteSHA else {
            let path = try await availablePath(
                startingAt: desiredPath,
                configuration: configuration,
                token: trimmedToken
            )
            let uploaded = try await api.put(
                path: path,
                content: content,
                sha: nil,
                configuration: configuration,
                token: trimmedToken
            )
            return GitHubPublishResult(
                path: uploaded.path,
                sha: uploaded.sha,
                repository: repository.identifier,
                branch: configuration.branch
            )
        }

        guard let current = try await api.file(
            path: remotePath,
            configuration: configuration,
            token: trimmedToken
        ),
              current.sha == remoteSHA else {
            throw GitHubPublishError.remoteChanged
        }

        if remotePath == desiredPath {
            let uploaded = try await api.put(
                path: remotePath,
                content: content,
                sha: current.sha,
                configuration: configuration,
                token: trimmedToken
            )
            return GitHubPublishResult(
                path: uploaded.path,
                sha: uploaded.sha,
                repository: repository.identifier,
                branch: configuration.branch
            )
        }

        let newPath = try await availablePath(
            startingAt: desiredPath,
            configuration: configuration,
            token: trimmedToken
        )
        let created = try await api.put(
            path: newPath,
            content: content,
            sha: nil,
            configuration: configuration,
            token: trimmedToken
        )
        do {
            try await api.delete(
                path: remotePath,
                sha: current.sha,
                configuration: configuration,
                token: trimmedToken
            )
        } catch {
            try? await api.delete(
                path: created.path,
                sha: created.sha,
                configuration: configuration,
                token: trimmedToken
            )
            throw error
        }
        return GitHubPublishResult(
            path: created.path,
            sha: created.sha,
            repository: repository.identifier,
            branch: configuration.branch
        )
    }

    static func markdown(for note: DailyNote) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day], from: note.date)
        let date = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        let escapedTitle = note.title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
        ---
        id: "\(note.id.uuidString)"
        date: "\(date)"
        title: "\(escapedTitle)"
        ---

        \(note.text)
        """
    }

    static func filename(for title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitHubPublishError.emptyTitle }

        let invalid = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:"))
        let sanitizedScalars = trimmed.unicodeScalars.map { invalid.contains($0) ? "-" : String($0) }
        var sanitized = sanitizedScalars.joined()
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }
        sanitized = sanitized.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        guard !sanitized.isEmpty else { throw GitHubPublishError.emptyTitle }
        return "\(sanitized).md"
    }

    private func availablePath(
        startingAt path: String,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> String {
        if try await api.file(path: path, configuration: configuration, token: token) == nil { return path }

        let extensionIndex = path.lastIndex(of: ".") ?? path.endIndex
        let stem = String(path[..<extensionIndex])
        let suffix = String(path[extensionIndex...])
        var number = 2
        while true {
            let candidate = "\(stem)-\(number)\(suffix)"
            if try await api.file(path: candidate, configuration: configuration, token: token) == nil {
                return candidate
            }
            number += 1
        }
    }
}

private struct GitHubRESTContentAPI: GitHubContentAPI {
    private let session = URLSession.shared

    func file(
        path: String,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> GitHubRemoteFile? {
        var request = try request(path: path, method: "GET", configuration: configuration, token: token)
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ref", value: configuration.branch)]
        request.url = components.url
        let (data, response) = try await session.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(FileResponse.self, from: data)
        return GitHubRemoteFile(path: decoded.path, sha: decoded.sha)
    }

    func put(
        path: String,
        content: String,
        sha: String?,
        configuration: GitHubConfiguration,
        token: String
    ) async throws -> GitHubRemoteFile {
        var request = try request(path: path, method: "PUT", configuration: configuration, token: token)
        request.httpBody = try JSONEncoder().encode(PutBody(
            message: sha == nil ? "Add \(path) from MyToDoBar" : "Update \(path) from MyToDoBar",
            content: Data(content.utf8).base64EncodedString(),
            branch: configuration.branch,
            sha: sha
        ))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(PutResponse.self, from: data)
        return GitHubRemoteFile(path: decoded.content.path, sha: decoded.content.sha)
    }

    func delete(
        path: String,
        sha: String,
        configuration: GitHubConfiguration,
        token: String
    ) async throws {
        var request = try request(path: path, method: "DELETE", configuration: configuration, token: token)
        request.httpBody = try JSONEncoder().encode(DeleteBody(
            message: "Rename \(path) from MyToDoBar",
            sha: sha,
            branch: configuration.branch
        ))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func request(
        path: String,
        method: String,
        configuration: GitHubConfiguration,
        token: String
    ) throws -> URLRequest {
        let repository = try configuration.repository
        var url = URL(string: "https://api.github.com")!
        for component in ["repos", repository.owner, repository.name, "contents"]
            + path.split(separator: "/").map(String.init) {
            url.appendPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("MyToDoBar", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw GitHubPublishError.requestFailed("응답을 확인할 수 없습니다.")
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).message)
                ?? "HTTP \(response.statusCode)"
            if response.statusCode == 409 || response.statusCode == 422 {
                throw GitHubPublishError.remoteChanged
            }
            throw GitHubPublishError.requestFailed(message)
        }
    }

    private struct FileResponse: Decodable { let path: String; let sha: String }
    private struct PutResponse: Decodable { let content: FileResponse }
    private struct ErrorResponse: Decodable { let message: String }
    private struct PutBody: Encodable { let message: String; let content: String; let branch: String; let sha: String? }
    private struct DeleteBody: Encodable { let message: String; let sha: String; let branch: String }
}
