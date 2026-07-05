# Upcoming Schedules Design

## Goal

Use the empty area above the monthly calendar to show future deadlines in chronological order. A user can register an item such as `카카오뱅크 지원` with a deadline of `7.10. 23:59`, then see and edit it without leaving the calendar.

## Scope

- Add, edit, and delete schedules from the calendar sidebar.
- Require a title, date, and time for every schedule.
- Show only schedules whose deadline is later than the current time.
- Keep expired schedules in local storage but hide them from the upcoming list.
- Do not add notifications, recurrence, categories, or system Calendar integration.

## Calendar Sidebar

Add a `다가오는 일정` section above the month header. The section has a fixed maximum height of 170 points so the calendar remains stable.

- A `+` button opens the schedule form in a popover.
- The list is sorted by deadline in ascending order.
- Three schedule cards are visible without scrolling at the standard sidebar width.
- Additional cards are available through vertical scrolling inside the section.
- The list remains global when the displayed month or selected date changes.
- The empty state reads `예정된 일정이 없습니다`.

Each card shows:

- Short date, such as `7.10.`
- Schedule title
- Weekday and time, such as `목요일 23:59`
- Relative remaining time, such as `5일 남음`

Long titles use a single line and truncate at the trailing edge. Clicking a card opens the same popover in edit mode.

## Schedule Form

The add and edit experiences use one compact popover containing:

- Title text field
- Date picker
- Time picker
- `하루 끝` shortcut that sets the selected date to 23:59
- Save button
- Delete button in edit mode

The form uses a compact 360-point width. Date and time use the same 160-by-28-point AppKit field-and-stepper control directly. Picker configuration is applied only at creation so rerenders do not reset the selected segment. Date enables AppKit's calendar overlay; time uses a fixed 24-hour locale such as `22:24`.

The title is trimmed before saving. An empty title or a deadline that is not later than the current time is rejected with an inline error. A persistence error leaves the popover open and displays the store error.

## Data Model

`ScheduleItem` contains:

- `id: UUID`
- `title: String`
- `deadline: Date`
- `createdAt: Date`

`ScheduleStore` owns schedule mutations and presentation queries. It stores all schedules, including expired schedules, in:

`~/Library/Application Support/MyToDoBar/schedules.json`

The JSON file is written atomically. If decoding fails, the store enters an unavailable state and blocks all mutations to protect the original file, matching `TodoStore` behavior.

## Time Behavior

The upcoming list is recalculated when:

- The store changes
- The calendar day changes
- The system clock changes
- The system time zone changes

Changing the selected calendar day or displayed month does not filter the upcoming list.

## Architecture

- `MyToDoBarCore`: `ScheduleItem` and pure sorting/filtering logic.
- `MyToDoBarKit`: JSON persistence and `ScheduleStore`.
- `MyToDoBar`: upcoming schedule list, cards, and add/edit popover.

The schedule domain stays separate from `TodoItem` because schedules have deadlines and expiry-based visibility, while TODOs are grouped by creation date and completion state.

## Testing

- Model decoding and equality.
- Upcoming filtering excludes deadlines at or before the reference time.
- Upcoming schedules are ordered by nearest deadline.
- Add, edit, and delete persist successfully.
- Empty titles and past deadlines are rejected.
- Corrupt JSON blocks overwrites and exposes an error.
- Save failures do not mutate in-memory schedules.
- Calendar sidebar builds successfully with the schedule UI.
- Manual visual verification covers narrow sidebar width, long titles, empty state, and scrolling with at least ten schedules.

## Acceptance Criteria

1. The calendar sidebar shows a `다가오는 일정` area above the month calendar.
2. The `+` button opens a popover that requires title, date, and time.
3. A saved future schedule appears immediately in chronological order.
4. Clicking a schedule opens it for editing and deletion.
5. More than three schedules scroll vertically without pushing the calendar downward.
6. A schedule disappears from the upcoming list after its deadline but remains in `schedules.json`.
7. Schedule data survives app restart.
8. Invalid or corrupt storage cannot silently overwrite the existing schedule file.
9. No notification permission is requested.
