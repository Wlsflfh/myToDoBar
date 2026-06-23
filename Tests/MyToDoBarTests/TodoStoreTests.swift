import Foundation
import Combine
import MyToDoBarCore
import XCTest
@testable import MyToDoBarKit

final class TodoStoreTests: XCTestCase {
    @MainActor
    func testTrimsAndPersistsValidInput() throws {
        let fixture = try Fixture()
        let store = fixture.makeStore()

        XCTAssertTrue(store.add(title: "  테스트 작성  "))
        XCTAssertFalse(store.add(title: " \n "))

        let restored = fixture.makeStore()
        XCTAssertEqual(restored.items.map(\.title), ["테스트 작성"])
        XCTAssertEqual(restored.items.first?.id, store.items.first?.id)
    }

    @MainActor
    func testPersistsCompletionWithoutMovingOriginalDay() throws {
        let fixture = try Fixture()
        let store = fixture.makeStore()
        XCTAssertTrue(store.add(title: "완료하기"))
        let createdAt = try XCTUnwrap(store.items.first?.createdAt)

        fixture.now = createdAt.addingTimeInterval(120)
        XCTAssertTrue(store.toggle(try XCTUnwrap(store.items.first)))

        let restored = fixture.makeStore()
        let item = try XCTUnwrap(restored.items.first)
        XCTAssertEqual(item.createdAt, createdAt)
        XCTAssertEqual(item.completedAt, fixture.now)
    }

    @MainActor
    func testDeletesAndPersistsItem() throws {
        let fixture = try Fixture()
        let store = fixture.makeStore()
        XCTAssertTrue(store.add(title: "삭제할 일"))
        XCTAssertTrue(store.add(title: "남길 일"))

        XCTAssertTrue(store.delete(try XCTUnwrap(store.items.first)))

        XCTAssertEqual(store.items.map(\.title), ["남길 일"])
        XCTAssertEqual(fixture.makeStore().items.map(\.title), ["남길 일"])
    }

    @MainActor
    func testRefreshesTodayWithoutRollingItemsForward() throws {
        let fixture = try Fixture()
        let store = fixture.makeStore()
        XCTAssertTrue(store.add(title: "첫날 미완료"))
        XCTAssertEqual(store.todayItems.count, 1)

        fixture.now = fixture.now.addingTimeInterval(86_400)
        store.refreshCurrentDate()

        XCTAssertTrue(store.todayItems.isEmpty)
        XCTAssertEqual(store.items.count, 1)
    }

    @MainActor
    func testCorruptFileBlocksOverwriteAndSurfacesError() throws {
        let fixture = try Fixture()
        try Data("not-json".utf8).write(to: fixture.fileURL)
        let store = fixture.makeStore()

        XCTAssertNotNil(store.storageState.message)
        XCTAssertFalse(store.add(title: "덮어쓰면 안 됨"))
        XCTAssertEqual(try String(contentsOf: fixture.fileURL, encoding: .utf8), "not-json")

        try Data("[]".utf8).write(to: fixture.fileURL)
        store.reload()
        XCTAssertEqual(store.storageState, .available)
        XCTAssertTrue(store.add(title: "복구 후 저장"))
    }

    @MainActor
    func testFailedSaveDoesNotChangeInMemoryItems() {
        let store = TodoStore(
            persistence: FailingPersistence(),
            calendar: .current,
            now: Date.init,
            notificationCenter: NotificationCenter()
        )

        XCTAssertFalse(store.add(title: "저장 실패"))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.storageState.message)
    }

    @MainActor
    func testForcedDateRefreshPublishesForTimeZoneChanges() throws {
        let fixture = try Fixture()
        let store = fixture.makeStore()
        var updateCount = 0
        let cancellable = store.objectWillChange.sink { updateCount += 1 }

        fixture.notificationCenter.post(name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(updateCount, 1)
        withExtendedLifetime(cancellable) {}
    }
}

private struct FailingPersistence: TodoPersisting {
    func load() throws -> [TodoItem] { [] }
    func save(_ items: [TodoItem]) throws { throw Failure.expected }

    private enum Failure: Error {
        case expected
    }
}

@MainActor
private final class Fixture {
    let directoryURL: URL
    let fileURL: URL
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let notificationCenter = NotificationCenter()

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        fileURL = directoryURL.appending(path: "todos.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func makeStore() -> TodoStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return TodoStore(
            persistence: JSONTodoPersistence(fileURL: fileURL),
            calendar: calendar,
            now: { [weak self] in self?.now ?? .distantPast },
            notificationCenter: notificationCenter
        )
    }
}
