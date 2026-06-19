import Foundation
import XCTest
@testable import MyToDoBarKit

final class DailyLogStoreTests: XCTestCase {
    @MainActor
    func testPersistsDiaryAndWorkoutForSameDate() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()

        XCTAssertTrue(store.setDiary("좋은 하루", on: fixture.firstDay))
        XCTAssertTrue(store.setWorkout("달리기 30분", on: fixture.firstDay))

        let restored = fixture.makeStore()
        XCTAssertEqual(restored.diary(on: fixture.firstDay), "좋은 하루")
        XCTAssertEqual(restored.workout(on: fixture.firstDay), "달리기 30분")
    }

    @MainActor
    func testKeepsRecordsSeparatedByDate() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()

        XCTAssertTrue(store.setDiary("첫째 날", on: fixture.firstDay))
        XCTAssertTrue(store.setDiary("둘째 날", on: fixture.secondDay))

        XCTAssertEqual(store.diary(on: fixture.firstDay), "첫째 날")
        XCTAssertEqual(store.diary(on: fixture.secondDay), "둘째 날")
    }

    @MainActor
    func testRemovesEmptyRecord() throws {
        let fixture = try DailyLogFixture()
        let store = fixture.makeStore()

        XCTAssertTrue(store.setWorkout("스쿼트", on: fixture.firstDay))
        XCTAssertTrue(store.setWorkout("", on: fixture.firstDay))

        XCTAssertTrue(store.logs.isEmpty)
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
