import Foundation
import XCTest
@testable import MyToDoBarKit

final class DailyLogStoreTests: XCTestCase {
    @MainActor
    func testPersistsMultipleNamedNotesForSameDate() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()

        let first = try XCTUnwrap(store.addNote(on: fixture.firstDay))
        let second = try XCTUnwrap(store.addNote(on: fixture.firstDay))
        XCTAssertTrue(store.setTitle("회의", for: first.id))
        XCTAssertTrue(store.setText("결정 사항", for: first.id))
        XCTAssertTrue(store.setPublishPath("contents/swift", for: first.id))
        XCTAssertTrue(store.setTitle("아이디어", for: second.id))
        XCTAssertTrue(store.setRemote(
            path: "contents/회의.md",
            sha: "abc123",
            repository: "Wlsflfh/TIL",
            branch: "main",
            for: first.id
        ))

        let restored = fixture.makeStore().notes(on: fixture.firstDay)
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.first { $0.id == first.id }?.title, "회의")
        XCTAssertEqual(restored.first { $0.id == first.id }?.text, "결정 사항")
        XCTAssertEqual(restored.first { $0.id == first.id }?.publishPath, "contents/swift")
        XCTAssertEqual(restored.first { $0.id == first.id }?.remotePath, "contents/회의.md")
        XCTAssertEqual(restored.first { $0.id == first.id }?.remoteSHA, "abc123")
        XCTAssertEqual(restored.first { $0.id == first.id }?.remoteRepository, "Wlsflfh/TIL")
        XCTAssertEqual(restored.first { $0.id == first.id }?.remoteBranch, "main")
        XCTAssertEqual(restored.first { $0.id == second.id }?.title, "아이디어")
    }

    @MainActor
    func testKeepsNotesSeparatedByDate() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()

        XCTAssertNotNil(store.addNote(on: fixture.firstDay))
        XCTAssertNotNil(store.addNote(on: fixture.secondDay))

        XCTAssertEqual(store.notes(on: fixture.firstDay).count, 1)
        XCTAssertEqual(store.notes(on: fixture.secondDay).count, 1)
    }

    @MainActor
    func testDeletesOneNoteWithoutRemovingOthers() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()
        let first = try XCTUnwrap(store.addNote(on: fixture.firstDay))
        let second = try XCTUnwrap(store.addNote(on: fixture.firstDay))

        XCTAssertTrue(store.deleteNote(id: first.id))
        XCTAssertEqual(store.notes(on: fixture.firstDay).map(\.id), [second.id])
    }

    @MainActor
    func testMigratesLegacyDiaryAndWorkoutToNamedNotes() throws {
        let fixture = try DailyLogFixture()
        let legacyJSON = """
        [{"id":"00000000-0000-0000-0000-000000000001","date":0,"diary":"좋은 하루","workout":"달리기 30분"}]
        """
        try Data(legacyJSON.utf8).write(to: fixture.fileURL)

        let notes = fixture.makeStore().notes
        XCTAssertEqual(notes.map(\.title), ["일기", "운동 일지"])
        XCTAssertEqual(notes.map(\.text), ["좋은 하루", "달리기 30분"])
    }
}

@MainActor
private final class DailyLogFixture {
    let directoryURL: URL
    let fileURL: URL
    let calendar: Calendar
    let firstDay: Date
    let secondDay: Date

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        fileURL = directoryURL.appending(path: "daily-logs.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        firstDay = calendar.date(from: DateComponents(year: 2026, month: 6, day: 14))!
        secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func makeStore() -> DailyLogStore {
        DailyLogStore(
            persistence: JSONDailyLogPersistence(fileURL: fileURL),
            calendar: calendar
        )
    }
}
