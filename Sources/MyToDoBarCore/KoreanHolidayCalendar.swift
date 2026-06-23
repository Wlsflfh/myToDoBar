import Foundation

public struct KoreanHolidayCalendar: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isHoliday(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return false
        }

        let monthDay = MonthDay(month: month, day: day)
        return Self.fixedHolidays.contains(monthDay)
            || Self.additionalHolidaysByYear[year, default: []].contains(monthDay)
    }

    private static let fixedHolidays: Set<MonthDay> = [
        MonthDay(month: 1, day: 1),
        MonthDay(month: 3, day: 1),
        MonthDay(month: 5, day: 5),
        MonthDay(month: 6, day: 6),
        MonthDay(month: 8, day: 15),
        MonthDay(month: 10, day: 3),
        MonthDay(month: 10, day: 9),
        MonthDay(month: 12, day: 25)
    ]

    // Lunar holidays, substitute holidays, and election days follow the annual official calendar.
    private static let additionalHolidaysByYear: [Int: Set<MonthDay>] = [
        2026: [
            MonthDay(month: 2, day: 16),
            MonthDay(month: 2, day: 17),
            MonthDay(month: 2, day: 18),
            MonthDay(month: 3, day: 2),
            MonthDay(month: 5, day: 24),
            MonthDay(month: 5, day: 25),
            MonthDay(month: 6, day: 3),
            MonthDay(month: 8, day: 17),
            MonthDay(month: 9, day: 24),
            MonthDay(month: 9, day: 25),
            MonthDay(month: 9, day: 26),
            MonthDay(month: 10, day: 5)
        ]
    ]
}

private struct MonthDay: Hashable, Sendable {
    let month: Int
    let day: Int
}
