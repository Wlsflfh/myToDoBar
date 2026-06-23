import Combine
import Foundation

public struct DailyNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var title: String
    public var text: String
    public var remotePath: String?
    public var remoteSHA: String?
    public var remoteRepository: String?
    public var remoteBranch: String?
    public var publishPath: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        title: String = "새 메모",
        text: String = "",
        remotePath: String? = nil,
        remoteSHA: String? = nil,
        remoteRepository: String? = nil,
        remoteBranch: String? = nil,
        publishPath: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.text = text
        self.remotePath = remotePath
        self.remoteSHA = remoteSHA
        self.remoteRepository = remoteRepository
        self.remoteBranch = remoteBranch
        self.publishPath = publishPath
    }
}

protocol DailyLogPersisting {
    func load() throws -> [DailyNote]
    func save(_ notes: [DailyNote]) throws
}

struct JSONDailyLogPersistence: DailyLogPersisting {
    let fileURL: URL
    var fileManager: FileManager = .default

    private struct LegacyDailyLog: Decodable {
        let date: Date
        let diary: String
        let workout: String
    }

    static func live(fileManager: FileManager = .default) -> JSONDailyLogPersistence {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appending(path: "MyToDoBar", directoryHint: .isDirectory)
        return JSONDailyLogPersistence(fileURL: directory.appending(path: "daily-logs.json"), fileManager: fileManager)
    }

    func load() throws -> [DailyNote] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)

        if let notes = try? JSONDecoder().decode([DailyNote].self, from: data) {
            return notes
        }

        let legacyLogs = try JSONDecoder().decode([LegacyDailyLog].self, from: data)
        return legacyLogs.flatMap { log in
            var notes: [DailyNote] = []
            if !log.diary.isEmpty {
                notes.append(DailyNote(date: log.date, title: "일기", text: log.diary))
            }
            if !log.workout.isEmpty {
                notes.append(DailyNote(date: log.date, title: "운동 일지", text: log.workout))
            }
            return notes
        }
    }

    func save(_ notes: [DailyNote]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(notes).write(to: fileURL, options: .atomic)
    }
}

@MainActor
public final class DailyLogStore: ObservableObject {
    @Published public private(set) var notes: [DailyNote] = []
    @Published public private(set) var errorMessage: String?

    private let persistence: any DailyLogPersisting
    private let calendar: Calendar

    public convenience init() {
        self.init(persistence: JSONDailyLogPersistence.live(), calendar: .autoupdatingCurrent)
    }

    init(persistence: any DailyLogPersisting, calendar: Calendar) {
        self.persistence = persistence
        self.calendar = calendar
        load()
    }

    public func notes(on date: Date) -> [DailyNote] {
        notes.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    @discardableResult
    public func addNote(on date: Date) -> DailyNote? {
        let note = DailyNote(date: calendar.startOfDay(for: date))
        return save(notes + [note]) ? note : nil
    }

    @discardableResult
    public func setTitle(_ title: String, for id: UUID) -> Bool {
        update(id: id) { $0.title = title }
    }

    @discardableResult
    public func setText(_ text: String, for id: UUID) -> Bool {
        update(id: id) { $0.text = text }
    }

    @discardableResult
    public func setPublishPath(_ path: String, for id: UUID) -> Bool {
        update(id: id) { $0.publishPath = path }
    }

    @discardableResult
    public func setRemote(
        path: String,
        sha: String,
        repository: String,
        branch: String,
        for id: UUID
    ) -> Bool {
        update(id: id) {
            $0.remotePath = path
            $0.remoteSHA = sha
            $0.remoteRepository = repository
            $0.remoteBranch = branch
        }
    }

    @discardableResult
    public func deleteNote(id: UUID) -> Bool {
        save(notes.filter { $0.id != id })
    }

    private func update(id: UUID, change: (inout DailyNote) -> Void) -> Bool {
        var updated = notes
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return false }
        change(&updated[index])
        return save(updated)
    }

    private func save(_ updated: [DailyNote]) -> Bool {
        do {
            try persistence.save(updated)
            notes = updated
            errorMessage = nil
            return true
        } catch {
            errorMessage = "메모를 저장하지 못했습니다."
            return false
        }
    }

    private func load() {
        do {
            notes = try persistence.load()
            errorMessage = nil
        } catch {
            errorMessage = "저장된 메모를 읽지 못했습니다."
        }
    }
}
