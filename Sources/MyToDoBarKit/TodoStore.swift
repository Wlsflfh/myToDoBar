import Combine
import Foundation
import MyToDoBarCore

protocol TodoPersisting {
    func load() throws -> [TodoItem]
    func save(_ items: [TodoItem]) throws
}

struct JSONTodoPersistence: TodoPersisting {
    let fileURL: URL
    var fileManager: FileManager = .default

    static func live(fileManager: FileManager = .default) -> JSONTodoPersistence {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appending(path: "MyToDoBar", directoryHint: .isDirectory)
        return JSONTodoPersistence(fileURL: directory.appending(path: "todos.json"), fileManager: fileManager)
    }

    func load() throws -> [TodoItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([TodoItem].self, from: data)
    }

    func save(_ items: [TodoItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}

public enum TodoStorageState: Equatable {
    case available
    case unavailable(message: String)

    public var message: String? {
        guard case let .unavailable(message) = self else { return nil }
        return message
    }
}

@MainActor
public final class TodoStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = []
    @Published public private(set) var currentDate: Date
    @Published public private(set) var storageState = TodoStorageState.available

    private let persistence: any TodoPersisting
    public let calendar: Calendar
    private let todoCalendar: TodoCalendar
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()

    public convenience init() {
        self.init(
            persistence: JSONTodoPersistence.live(),
            calendar: .autoupdatingCurrent,
            now: Date.init,
            notificationCenter: .default
        )
    }

    init(
        persistence: any TodoPersisting,
        calendar: Calendar,
        now: @escaping () -> Date,
        notificationCenter: NotificationCenter
    ) {
        self.persistence = persistence
        self.calendar = calendar
        todoCalendar = TodoCalendar(calendar: calendar)
        self.now = now
        currentDate = now()
        load()

        notificationCenter.publisher(for: .NSCalendarDayChanged)
            .merge(with: notificationCenter.publisher(for: NSNotification.Name.NSSystemClockDidChange))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshCurrentDate()
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshCurrentDate(force: true)
            }
            .store(in: &cancellables)
    }

    public var todayItems: [TodoItem] {
        todoCalendar.items(on: currentDate, from: items)
    }

    public var countsByDay: [Date: Int] {
        todoCalendar.countsByDay(from: items)
    }

    public func items(on date: Date) -> [TodoItem] {
        todoCalendar.items(on: date, from: items)
    }

    @discardableResult
    public func add(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, storageState == .available else { return false }

        var updatedItems = items
        updatedItems.append(TodoItem(title: trimmed, createdAt: now()))
        return persist(updatedItems)
    }

    @discardableResult
    public func toggle(_ item: TodoItem) -> Bool {
        guard storageState == .available, let index = items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }

        var updatedItems = items
        updatedItems[index].toggleCompletion(at: now())
        return persist(updatedItems)
    }

    @discardableResult
    public func delete(_ item: TodoItem) -> Bool {
        guard storageState == .available, items.contains(where: { $0.id == item.id }) else {
            return false
        }

        return persist(items.filter { $0.id != item.id })
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
                message: "저장된 TODO를 읽지 못했습니다. 원본 파일을 보호하기 위해 변경을 중단했습니다."
            )
        }
    }

    private func persist(_ updatedItems: [TodoItem]) -> Bool {
        do {
            try persistence.save(updatedItems)
            items = updatedItems
            storageState = .available
            return true
        } catch {
            storageState = .unavailable(
                message: "TODO를 저장하지 못했습니다. 디스크 공간과 파일 권한을 확인한 뒤 다시 시도해 주세요."
            )
            return false
        }
    }
}
