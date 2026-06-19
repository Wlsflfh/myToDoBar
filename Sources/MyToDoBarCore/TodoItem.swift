import Foundation

public struct TodoItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public mutating func toggleCompletion(at date: Date = Date()) {
        completedAt = isCompleted ? nil : date
    }
}
