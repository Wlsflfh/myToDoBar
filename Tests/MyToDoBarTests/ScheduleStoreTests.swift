import Combine
import Foundation
import MyToDoBarCore
import XCTest
@testable import MyToDoBarKit

final class ScheduleStoreTests: XCTestCase {
    @MainActor
    func testAddsUpdatesDeletesAndPersistsSchedules() throws {
        let fixture = try ScheduleFixture()
        let store = fixture.makeStore()
        let deadline = fixture.now.addingTimeInterval(3_600)

        let id = try XCTUnwrap(store.add(title: "  카카오뱅크 지원  ", deadline: deadline))
        XCTAssertEqual(store.items.first?.title, "카카오뱅크 지원")

        XCTAssertTrue(store.update(
            id: id,
            title: "카카오뱅크 최종 지원",
            deadline: deadline.addingTimeInterval(60)
        ))
        XCTAssertEqual(fixture.makeStore().items.first?.title, "카카오뱅크 최종 지원")

        XCTAssertTrue(store.delete(id: id))
        XCTAssertTrue(fixture.makeStore().items.isEmpty)
    }

    @MainActor
    func testRejectsEmptyTitlesAndNonFutureDeadlines() throws {
        let fixture = try ScheduleFixture()
        let store = fixture.makeStore()

        XCTAssertNil(store.add(title: "  ", deadline: fixture.now.addingTimeInterval(60)))
        XCTAssertNil(store.add(title: "지남", deadline: fixture.now))
        XCTAssertNil(store.add(title: "과거", deadline: fixture.now.addingTimeInterval(-1)))
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testUpcomingItemsRefreshWhenClockChanges() throws {
        let fixture = try ScheduleFixture()
        let store = fixture.makeStore()
        let deadline = fixture.now.addingTimeInterval(60)
        let id = try XCTUnwrap(store.add(title: "곧 마감", deadline: deadline))
        XCTAssertEqual(store.upcomingItems.map(\.id), [id])

        fixture.now = deadline
        fixture.notificationCenter.post(name: NSNotification.Name.NSSystemClockDidChange, object: nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(store.upcomingItems.isEmpty)
        XCTAssertEqual(store.items.map(\.id), [id])
    }

    @MainActor
    func testCorruptFileBlocksOverwriteAndCanReload() throws {
        let fixture = try ScheduleFixture(contents: Data("not-json".utf8))
        let store = fixture.makeStore()

        XCTAssertNotNil(store.storageState.message)
        XCTAssertNil(store.add(title: "보호", deadline: fixture.now.addingTimeInterval(60)))
        XCTAssertEqual(try String(contentsOf: fixture.fileURL, encoding: .utf8), "not-json")

        try Data("[]".utf8).write(to: fixture.fileURL)
        store.reload()
        XCTAssertEqual(store.storageState, .available)
        XCTAssertNotNil(store.add(title: "복구", deadline: fixture.now.addingTimeInterval(60)))
    }

    @MainActor
    func testFailedSaveDoesNotChangeInMemoryItems() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = ScheduleStore(
            persistence: FailingSchedulePersistence(),
            calendar: .current,
            now: { now },
            notificationCenter: NotificationCenter()
        )

        XCTAssertNil(store.add(title: "저장 실패", deadline: now.addingTimeInterval(60)))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.storageState.message)
    }
}

private struct FailingSchedulePersistence: SchedulePersisting {
    func load() throws -> [ScheduleItem] { [] }
    func save(_ items: [ScheduleItem]) throws { throw Failure.expected }

    private enum Failure: Error {
        case expected
    }
}

@MainActor
private final class ScheduleFixture {
    let directoryURL: URL
    let fileURL: URL
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let notificationCenter = NotificationCenter()

    init(contents: Data? = nil) throws {
        directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        fileURL = directoryURL.appending(path: "schedules.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        if let contents {
            try contents.write(to: fileURL)
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func makeStore() -> ScheduleStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return ScheduleStore(
            persistence: JSONSchedulePersistence(fileURL: fileURL),
            calendar: calendar,
            now: { [weak self] in self?.now ?? .distantPast },
            notificationCenter: notificationCenter
        )
    }
}
