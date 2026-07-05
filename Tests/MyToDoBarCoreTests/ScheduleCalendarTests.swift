import Foundation
import XCTest
@testable import MyToDoBarCore

final class ScheduleCalendarTests: XCTestCase {
    func testReturnsOnlyFutureSchedulesOrderedByDeadline() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = [
            ScheduleItem(title: "나중", deadline: now.addingTimeInterval(200), createdAt: now),
            ScheduleItem(title: "지남", deadline: now, createdAt: now),
            ScheduleItem(title: "먼저", deadline: now.addingTimeInterval(100), createdAt: now)
        ]

        let upcoming = ScheduleCalendar().upcoming(from: items, after: now)

        XCTAssertEqual(upcoming.map(\.title), ["먼저", "나중"])
    }

    func testUsesCreationOrderWhenDeadlinesMatch() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deadline = now.addingTimeInterval(100)
        let items = [
            ScheduleItem(title: "두 번째", deadline: deadline, createdAt: now.addingTimeInterval(1)),
            ScheduleItem(title: "첫 번째", deadline: deadline, createdAt: now)
        ]

        let upcoming = ScheduleCalendar().upcoming(from: items, after: now)

        XCTAssertEqual(upcoming.map(\.title), ["첫 번째", "두 번째"])
    }
}
