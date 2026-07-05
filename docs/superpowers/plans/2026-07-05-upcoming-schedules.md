# Upcoming Schedules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent, editable list of future schedules above the monthly calendar, ordered by the nearest deadline.

**Architecture:** Keep schedules separate from TODOs. `MyToDoBarCore` owns the value type and pure upcoming query, `MyToDoBarKit` owns guarded JSON persistence and time refreshes, and the SwiftUI app owns the compact list and add/edit popover.

**Tech Stack:** Swift 6.2, SwiftUI, Combine, Foundation JSON persistence, XCTest, macOS 14+

---

## File Structure

- Create `Sources/MyToDoBarCore/ScheduleItem.swift`: schedule value type and pure upcoming sorting/filtering.
- Create `Tests/MyToDoBarCoreTests/ScheduleCalendarTests.swift`: deadline boundary and ordering tests.
- Create `Sources/MyToDoBarKit/ScheduleStore.swift`: JSON persistence, storage protection, mutations, and clock refreshes.
- Create `Tests/MyToDoBarTests/ScheduleStoreTests.swift`: persistence, validation, mutation, and failure tests.
- Create `Sources/MyToDoBar/UpcomingSchedulesView.swift`: list, cards, relative time text, and add/edit popover.
- Modify `Sources/MyToDoBar/HistoryView.swift`: place the schedule section above the month calendar.
- Modify `Sources/MyToDoBar/MyToDoBarApp.swift`: create and inject the shared schedule store.
- Modify `README.md` and `docs/product-spec.md`: document schedules and remove deadline display from non-goals.

### Task 1: Schedule Domain

**Files:**
- Create: `Sources/MyToDoBarCore/ScheduleItem.swift`
- Create: `Tests/MyToDoBarCoreTests/ScheduleCalendarTests.swift`

- [ ] **Step 1: Write failing upcoming-query tests**

```swift
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

        XCTAssertEqual(ScheduleCalendar().upcoming(from: items, after: now).map(\.title), ["먼저", "나중"])
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift test --filter ScheduleCalendarTests
```

Expected: compilation fails because `ScheduleItem` and `ScheduleCalendar` do not exist.

- [ ] **Step 3: Add the minimal domain implementation**

```swift
import Foundation

public struct ScheduleItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var deadline: Date
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, deadline: Date, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.createdAt = createdAt
    }
}

public struct ScheduleCalendar: Sendable {
    public init() {}

    public func upcoming(from items: [ScheduleItem], after date: Date) -> [ScheduleItem] {
        items.filter { $0.deadline > date }.sorted {
            if $0.deadline == $1.deadline { return $0.createdAt < $1.createdAt }
            return $0.deadline < $1.deadline
        }
    }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run `swift test --filter ScheduleCalendarTests`.

Expected: one test passes with zero failures.

### Task 2: Guarded Schedule Persistence

**Files:**
- Create: `Sources/MyToDoBarKit/ScheduleStore.swift`
- Create: `Tests/MyToDoBarTests/ScheduleStoreTests.swift`

- [ ] **Step 1: Write failing store tests**

Create `ScheduleStoreTests` with these concrete cases:

```swift
@MainActor
func testAddsUpdatesDeletesAndPersistsSchedules() throws {
    let fixture = try ScheduleFixture()
    let store = fixture.makeStore()
    let deadline = fixture.now.addingTimeInterval(3_600)

    let id = try XCTUnwrap(store.add(title: "  카카오뱅크 지원  ", deadline: deadline))
    XCTAssertEqual(store.items.first?.title, "카카오뱅크 지원")
    XCTAssertTrue(store.update(id: id, title: "카카오뱅크 최종 지원", deadline: deadline.addingTimeInterval(60)))
    XCTAssertEqual(fixture.makeStore().items.first?.title, "카카오뱅크 최종 지원")
    XCTAssertTrue(store.delete(id: id))
    XCTAssertTrue(fixture.makeStore().items.isEmpty)
}

@MainActor
func testRejectsEmptyTitlesAndNonFutureDeadlines() throws {
    let fixture = try ScheduleFixture()
    let store = fixture.makeStore()
    XCTAssertNil(store.add(title: "  ", deadline: fixture.now.addingTimeInterval(60)))
    XCTAssertNil(store.add(title: "지남", deadline: fixture.now))
}

@MainActor
func testCorruptFileBlocksOverwrite() throws {
    let fixture = try ScheduleFixture(contents: Data("not-json".utf8))
    let store = fixture.makeStore()
    XCTAssertNotNil(store.storageState.message)
    XCTAssertNil(store.add(title: "보호", deadline: fixture.now.addingTimeInterval(60)))
    XCTAssertEqual(try String(contentsOf: fixture.fileURL, encoding: .utf8), "not-json")
}
```

Add this persistence double and assert that a failed `add` leaves `items` empty:

```swift
private struct FailingSchedulePersistence: SchedulePersisting {
    func load() throws -> [ScheduleItem] { [] }
    func save(_ items: [ScheduleItem]) throws { throw Failure.expected }

    private enum Failure: Error { case expected }
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run `swift test --filter ScheduleStoreTests`.

Expected: compilation fails because `ScheduleStore` is missing.

- [ ] **Step 3: Implement persistence and store**

Use `JSONSchedulePersistence.live()` with `schedules.json`, atomic writes, and a `ScheduleStorageState` matching `TodoStorageState`. Implement these public operations:

```swift
public var upcomingItems: [ScheduleItem] {
    ScheduleCalendar().upcoming(from: items, after: currentDate)
}

@discardableResult
public func add(title: String, deadline: Date) -> UUID?

@discardableResult
public func update(id: UUID, title: String, deadline: Date) -> Bool

@discardableResult
public func delete(id: UUID) -> Bool

public func refreshCurrentDate(force: Bool = false)
public func reload()
```

Validate trimmed titles, require `deadline > now()`, save before publishing updated items, and subscribe to day, clock, and time-zone notifications.

- [ ] **Step 4: Run schedule store and full tests**

Run:

```bash
swift test --filter ScheduleStoreTests
swift test
```

Expected: all tests pass with zero failures.

### Task 3: Inject the Store into the Calendar Window

**Files:**
- Modify: `Sources/MyToDoBar/MyToDoBarApp.swift`
- Modify: `Sources/MyToDoBar/HistoryView.swift`

- [ ] **Step 1: Add the shared state object**

```swift
@StateObject private var scheduleStore = ScheduleStore()
```

Pass it into the history window:

```swift
HistoryView(
    store: store,
    dailyLogStore: dailyLogStore,
    scheduleStore: scheduleStore,
    githubSettings: githubSettings
)
```

- [ ] **Step 2: Add the HistoryView dependency and placement**

Add `@ObservedObject var scheduleStore: ScheduleStore`, then make the sidebar a vertical stack:

```swift
VStack(spacing: 16) {
    UpcomingSchedulesView(store: scheduleStore, calendar: store.calendar)
    MonthCalendarView(
        displayedMonth: $displayedMonth,
        selectedDate: $selectedDate,
        countsByDay: store.countsByDay,
        calendar: store.calendar
    )
}
.padding()
```

- [ ] **Step 3: Build and verify integration**

Run `swift build`.

Expected: build succeeds with no Swift compiler errors.

### Task 4: Upcoming List and Add/Edit Popover

**Files:**
- Create: `Sources/MyToDoBar/UpcomingSchedulesView.swift`

- [ ] **Step 1: Implement the fixed-height upcoming list**

Build a `VStack` with a `다가오는 일정` heading and `+` button. Use a vertical `ScrollView` capped at 170 points. Render `store.upcomingItems` with buttons so clicking a card sets `editingSchedule` and opens the popover. The empty state must display `예정된 일정이 없습니다`.

Card formatting:

```swift
Text(item.deadline.formatted(.dateTime.month().day()))
Text(item.title).lineLimit(1).truncationMode(.tail)
Text("\(item.deadline.formatted(.dateTime.weekday(.wide).hour().minute())) · \(remainingText)")
```

Use `TimelineView(.periodic(from: .now, by: 60))` around the list so deadlines disappear and relative labels update while the window stays open.

- [ ] **Step 2: Implement one reusable schedule form**

The popover contains a title field, separate graphical date and time pickers, an inline error, Save, Cancel, and Delete in edit mode. Combine selected date and time using the injected calendar before calling the store.

```swift
DatePicker("날짜", selection: $deadline, displayedComponents: .date)
DatePicker("시간", selection: $deadline, displayedComponents: .hourAndMinute)
```

Keep the popover open when validation or persistence fails. Close only after the store mutation returns success.

- [ ] **Step 3: Build and manually verify the visual states**

Run `swift build`, then create the app bundle with `./scripts/build-app.sh` using the configured Xcode toolchain.

Verify:

- Empty schedule state
- One long-title schedule
- Ten schedules with internal vertical scrolling
- Add, edit, and delete popovers
- Calendar position remains stable
- Expired schedule disappears after the timeline refresh

### Task 5: Documentation and Delivery

**Files:**
- Modify: `README.md`
- Modify: `docs/product-spec.md`

- [ ] **Step 1: Update project documentation**

Document the upcoming schedule feature, `schedules.json`, required title/date/time, automatic hiding after deadline, and absence of notifications. Move deadline display out of the product spec non-goals while keeping notifications and recurring schedules excluded.

- [ ] **Step 2: Run final verification**

Run the full test suite, `git diff --check`, build the app bundle, and verify it using:

```bash
codesign --verify --deep --strict --verbose=2 dist/MyToDoBar.app
```

Expected: all tests pass, diff check is clean, and codesign reports a valid bundle.

- [ ] **Step 3: Reinstall the app**

Replace `/Applications/MyToDoBar.app` with `dist/MyToDoBar.app`, then compare executable SHA-256 hashes and verify the installed signature.

- [ ] **Step 4: Commit and push**

Stage only the schedule implementation, tests, and documentation. Commit with:

```bash
git commit -m "Add upcoming schedules to calendar"
git push origin main
```

Expected: local `HEAD` and `origin/main` resolve to the same commit.
