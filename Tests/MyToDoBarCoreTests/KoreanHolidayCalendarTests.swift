import Foundation
import XCTest
@testable import MyToDoBarCore

final class KoreanHolidayCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    func testRecognizesFixedPublicHoliday() {
        XCTAssertTrue(holidays.isHoliday(date(year: 2026, month: 6, day: 6)))
    }

    func testRecognizes2026LunarAndSubstituteHolidays() {
        XCTAssertTrue(holidays.isHoliday(date(year: 2026, month: 2, day: 17)))
        XCTAssertTrue(holidays.isHoliday(date(year: 2026, month: 5, day: 25)))
        XCTAssertTrue(holidays.isHoliday(date(year: 2026, month: 9, day: 25)))
    }

    func testRecognizes2026NationwideElectionDay() {
        XCTAssertTrue(holidays.isHoliday(date(year: 2026, month: 6, day: 3)))
    }

    func testDoesNotMarkOrdinaryWeekdayAsHoliday() {
        XCTAssertFalse(holidays.isHoliday(date(year: 2026, month: 6, day: 4)))
    }

    private var holidays: KoreanHolidayCalendar {
        KoreanHolidayCalendar(calendar: calendar)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
