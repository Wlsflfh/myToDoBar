import Foundation

public struct ScheduleItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var deadline: Date
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        deadline: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.createdAt = createdAt
    }
}

public struct ScheduleCalendar: Sendable {
    public init() {}

    public func upcoming(from items: [ScheduleItem], after date: Date) -> [ScheduleItem] {
        items
            .filter { $0.deadline > date }
            .sorted {
                if $0.deadline == $1.deadline {
                    return $0.createdAt < $1.createdAt
                }
                return $0.deadline < $1.deadline
            }
    }

    public func endOfDay(for date: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: 23, minute: 59, second: 0, of: date)
    }

    public func koreanDateLabel(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월 \(components.day ?? 0)일"
    }
}
