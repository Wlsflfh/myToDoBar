import Combine
import Foundation

public struct DailyLog: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var diary: String
    public var workout: String

    public init(
        id: UUID = UUID(),
        date: Date,
        diary: String = "",
        workout: String = ""
    ) {
        self.id = id
        self.date = date
        self.diary = diary
        self.workout = workout
    }
}

protocol DailyLogPersisting {
    func load() throws -> [DailyLog]
    func save(_ logs: [DailyLog]) throws
}

struct JSONDailyLogPersistence: DailyLogPersisting {
    let fileURL: URL
    var fileManager: FileManager = .default

    static func live(fileManager: FileManager = .default) -> JSONDailyLogPersistence {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appending(path: "MyToDoBar", directoryHint: .isDirectory)
        return JSONDailyLogPersistence(fileURL: directory.appending(path: "daily-logs.json"), fileManager: fileManager)
    }

    func load() throws -> [DailyLog] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([DailyLog].self, from: Data(contentsOf: fileURL))
    }

    func save(_ logs: [DailyLog]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(logs).write(to: fileURL, options: .atomic)
    }
}

@MainActor
public final class DailyLogStore: ObservableObject {
    @Published public private(set) var logs: [DailyLog] = []
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

    public func diary(on date: Date) -> String {
        log(on: date)?.diary ?? ""
    }

    public func workout(on date: Date) -> String {
        log(on: date)?.workout ?? ""
    }

    @discardableResult
    public func setDiary(_ text: String, on date: Date) -> Bool {
        update(on: date) { $0.diary = text }
    }

    @discardableResult
    public func setWorkout(_ text: String, on date: Date) -> Bool {
        update(on: date) { $0.workout = text }
    }

    private func log(on date: Date) -> DailyLog? {
        logs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func update(on date: Date, change: (inout DailyLog) -> Void) -> Bool {
        var updated = logs
        if let index = updated.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            change(&updated[index])
            if updated[index].diary.isEmpty, updated[index].workout.isEmpty {
                updated.remove(at: index)
            }
        } else {
            var newLog = DailyLog(date: calendar.startOfDay(for: date))
            change(&newLog)
            guard !newLog.diary.isEmpty || !newLog.workout.isEmpty else { return true }
            updated.append(newLog)
        }

        do {
            try persistence.save(updated)
            logs = updated
            errorMessage = nil
            return true
        } catch {
            errorMessage = "기록을 저장하지 못했습니다."
            return false
        }
    }

    private func load() {
        do {
            logs = try persistence.load()
            errorMessage = nil
        } catch {
            errorMessage = "저장된 일기와 운동 기록을 읽지 못했습니다."
        }
    }
}
