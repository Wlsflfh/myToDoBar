import Foundation
import XCTest
@testable import MyToDoBarCore

final class TodoCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testFiltersItemsByOriginalCreationDay() {
        let firstDay = Date(timeIntervalSince1970: 1_700_000_000)
        let nextDay = firstDay.addingTimeInterval(86_400)
        let items = [
            TodoItem(title: "첫날", createdAt: firstDay),
            TodoItem(title: "다음날", createdAt: nextDay)
        ]

        let result = TodoCalendar(calendar: calendar).items(on: firstDay, from: items)

        XCTAssertEqual(result.map(\.title), ["첫날"])
    }

    func testTogglesCompletionWithoutChangingOriginalDay() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        var item = TodoItem(title: "체크하기", createdAt: createdAt)

        item.toggleCompletion(at: createdAt.addingTimeInterval(60))

        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.createdAt, createdAt)
    }

    func testSortsItemsByCreationTime() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let items = [
            TodoItem(title: "나중", createdAt: day.addingTimeInterval(120)),
            TodoItem(title: "먼저", createdAt: day.addingTimeInterval(60))
        ]

        let result = TodoCalendar(calendar: calendar).items(on: day, from: items)

        XCTAssertEqual(result.map(\.title), ["먼저", "나중"])
    }

    func testCountsItemsByOriginalDayRegardlessOfCompletion() {
        let firstDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let nextDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let items = [
            TodoItem(title: "완료", createdAt: firstDay, completedAt: nextDay),
            TodoItem(title: "미완료", createdAt: firstDay.addingTimeInterval(60)),
            TodoItem(title: "다음 날", createdAt: nextDay)
        ]

        let counts = TodoCalendar(calendar: calendar).countsByDay(from: items)

        XCTAssertEqual(counts[firstDay], 2)
        XCTAssertEqual(counts[nextDay], 1)
    }

    func testBuildsMonthGridUsingCalendarsFirstWeekday() {
        var mondayFirstCalendar = calendar
        mondayFirstCalendar.firstWeekday = 2
        let month = mondayFirstCalendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!

        let days = TodoCalendar(calendar: mondayFirstCalendar).daysInMonth(containing: month)

        XCTAssertEqual(days.count, 35)
        XCTAssertEqual(mondayFirstCalendar.component(.weekday, from: days[0].date), 2)
        XCTAssertEqual(days.filter(\.isInDisplayedMonth).count, 29)
    }
}
