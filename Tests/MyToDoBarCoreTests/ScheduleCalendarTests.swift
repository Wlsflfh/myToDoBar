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

    func testEndOfDayKeepsDateAndSetsTimeTo2359() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 7,
            hour: 8,
            minute: 16
        )))

        let result = try XCTUnwrap(ScheduleCalendar().endOfDay(for: date, calendar: calendar))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 7)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 0)
    }

    func testFormatsKoreanDateWithYearMonthAndDayUnits() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5)))

        let label = ScheduleCalendar().koreanDateLabel(for: date, calendar: calendar)

        XCTAssertEqual(label, "2026년 7월 5일")
    }

    func testAppliesEditableKoreanDateWithoutChangingTime() throws {
        let calendar = seoulCalendar
        let original = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 5,
            hour: 20,
            minute: 44
        )))

        let result = try XCTUnwrap(ScheduleCalendar().applying(
            koreanDateLabel: "2026년 7월 10일",
            to: original,
            calendar: calendar
        ))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 10)
        XCTAssertEqual(components.hour, 20)
        XCTAssertEqual(components.minute, 44)
    }

    func testAppliesEditableKoreanTimeWithoutChangingDate() throws {
        let calendar = seoulCalendar
        let original = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 5,
            hour: 20,
            minute: 44
        )))

        let result = try XCTUnwrap(ScheduleCalendar().applying(
            koreanTimeLabel: "오후 11:59",
            to: original,
            calendar: calendar
        ))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 5)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
    }

    private var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
}
