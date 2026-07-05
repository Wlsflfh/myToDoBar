import Combine
import Foundation
import MyToDoBarCore

protocol SchedulePersisting {
    func load() throws -> [ScheduleItem]
    func save(_ items: [ScheduleItem]) throws
}

struct JSONSchedulePersistence: SchedulePersisting {
    let fileURL: URL
    var fileManager: FileManager = .default

    static func live(fileManager: FileManager = .default) -> JSONSchedulePersistence {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appending(path: "MyToDoBar", directoryHint: .isDirectory)
        return JSONSchedulePersistence(
            fileURL: directory.appending(path: "schedules.json"),
            fileManager: fileManager
        )
    }

    func load() throws -> [ScheduleItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ScheduleItem].self, from: data)
    }

    func save(_ items: [ScheduleItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

public enum ScheduleStorageState: Equatable {
    case available
    case unavailable(message: String)

    public var message: String? {
        guard case let .unavailable(message) = self else { return nil }
        return message
    }
}

@MainActor
public final class ScheduleStore: ObservableObject {
    @Published public private(set) var items: [ScheduleItem] = []
    @Published public private(set) var currentDate: Date
    @Published public private(set) var storageState = ScheduleStorageState.available

    private let persistence: any SchedulePersisting
    private let calendar: Calendar
    private let scheduleCalendar = ScheduleCalendar()
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()

    public convenience init() {
        self.init(
            persistence: JSONSchedulePersistence.live(),
            calendar: .autoupdatingCurrent,
            now: Date.init,
            notificationCenter: .default
        )
    }

    init(
        persistence: any SchedulePersisting,
        calendar: Calendar,
        now: @escaping () -> Date,
        notificationCenter: NotificationCenter
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.now = now
        currentDate = now()
        load()

        notificationCenter.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshCurrentDate()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSNotification.Name.NSSystemClockDidChange)
            .merge(with: notificationCenter.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshCurrentDate(force: true)
            }
            .store(in: &cancellables)
    }

    public var upcomingItems: [ScheduleItem] {
        scheduleCalendar.upcoming(from: items, after: currentDate)
    }

    @discardableResult
    public func add(title: String, deadline: Date) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, deadline > now(), storageState == .available else { return nil }

        let item = ScheduleItem(title: trimmed, deadline: deadline, createdAt: now())
        var updatedItems = items
        updatedItems.append(item)
        return persist(updatedItems) ? item.id : nil
    }

    @discardableResult
    public func update(id: UUID, title: String, deadline: Date) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              deadline > now(),
              storageState == .available,
              let index = items.firstIndex(where: { $0.id == id }) else {
            return false
        }

        var updatedItems = items
        updatedItems[index].title = trimmed
        updatedItems[index].deadline = deadline
        return persist(updatedItems)
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        guard storageState == .available, items.contains(where: { $0.id == id }) else { return false }
        return persist(items.filter { $0.id != id })
    }

    public func refreshCurrentDate(force: Bool = false) {
        let refreshedDate = now()
        guard force || !calendar.isDate(refreshedDate, inSameDayAs: currentDate) else { return }
        currentDate = refreshedDate
    }

    public func reload() {
        load()
    }

    private func load() {
        do {
            items = try persistence.load()
            storageState = .available
        } catch {
            storageState = .unavailable(
                message: "저장된 일정을 읽지 못했습니다. 원본 파일을 보호하기 위해 변경을 중단했습니다."
            )
        }
    }

    private func persist(_ updatedItems: [ScheduleItem]) -> Bool {
        do {
            try persistence.save(updatedItems)
            items = updatedItems
            storageState = .available
            return true
        } catch {
            storageState = .unavailable(
                message: "일정을 저장하지 못했습니다. 디스크 공간과 파일 권한을 확인한 뒤 다시 시도해 주세요."
            )
            return false
        }
    }
}
