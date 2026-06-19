import Foundation

public struct TodoCalendarDay: Equatable, Sendable {
    public let date: Date
    public let isInDisplayedMonth: Bool

    public init(date: Date, isInDisplayedMonth: Bool) {
        self.date = date
        self.isInDisplayedMonth = isInDisplayedMonth
    }
}

public struct TodoCalendar: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func items(on date: Date, from items: [TodoItem]) -> [TodoItem] {
        items
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func countsByDay(from items: [TodoItem]) -> [Date: Int] {
        Dictionary(grouping: items, by: { calendar.startOfDay(for: $0.createdAt) })
            .mapValues(\.count)
    }

    public func daysInMonth(containing date: Date) -> [TodoCalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: date),
            let dayRange = calendar.range(of: .day, in: .month, for: date)
        else {
            return []
        }

        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let dayCount = dayRange.count
        let cellCount = Int(ceil(Double(leadingDays + dayCount) / 7.0)) * 7

        return (0..<cellCount).compactMap { index in
            guard let cellDate = calendar.date(byAdding: .day, value: index - leadingDays, to: firstDay) else {
                return nil
            }

            return TodoCalendarDay(
                date: cellDate,
                isInDisplayedMonth: calendar.isDate(cellDate, equalTo: firstDay, toGranularity: .month)
            )
        }
    }
}
