import MyToDoBarCore
import MyToDoBarKit
import SwiftUI

private enum HistorySection: String, CaseIterable, Identifiable {
    case todos = "할 일"
    case diary = "일기"
    case workout = "운동"

    var id: Self { self }
}

private enum TodoFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case incomplete = "미완료"
    case completed = "완료"

    var id: Self { self }
}

struct HistoryView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var dailyLogStore: DailyLogStore
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var section = HistorySection.todos
    @State private var todoFilter = TodoFilter.all

    var body: some View {
        NavigationSplitView {
            MonthCalendarView(
                displayedMonth: $displayedMonth,
                selectedDate: $selectedDate,
                countsByDay: store.countsByDay,
                calendar: store.calendar
            )
            .padding()
            .navigationTitle("전체 보기")
        } detail: {
            VStack(spacing: 0) {
                Picker("기록 종류", selection: $section) {
                    ForEach(HistorySection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                switch section {
                case .todos:
                    TodoHistoryDetail(store: store, date: selectedDate, filter: $todoFilter)
                case .diary:
                    DailyTextEditor(
                        title: "오늘의 일기",
                        prompt: "오늘 있었던 일이나 생각을 적어보세요.",
                        text: Binding(
                            get: { dailyLogStore.diary(on: selectedDate) },
                            set: { dailyLogStore.setDiary($0, on: selectedDate) }
                        ),
                        errorMessage: dailyLogStore.errorMessage
                    )
                case .workout:
                    DailyTextEditor(
                        title: "운동 일지",
                        prompt: "운동 종류, 세트, 횟수, 시간 등을 적어보세요.",
                        text: Binding(
                            get: { dailyLogStore.workout(on: selectedDate) },
                            set: { dailyLogStore.setWorkout($0, on: selectedDate) }
                        ),
                        errorMessage: dailyLogStore.errorMessage
                    )
                }
            }
            .navigationTitle(selectedDate.formatted(date: .long, time: .omitted))
        }
    }
}

private struct TodoHistoryDetail: View {
    @ObservedObject var store: TodoStore
    let date: Date
    @Binding var filter: TodoFilter

    private var items: [TodoItem] {
        store.items(on: date).filter { item in
            switch filter {
            case .all: true
            case .incomplete: !item.isCompleted
            case .completed: item.isCompleted
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("상태", selection: $filter) {
                ForEach(TodoFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .padding()

            List(items) { item in
                HStack {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? Color.secondary : Color.orange)
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    Spacer()
                    Text(item.isCompleted ? "완료" : "미완료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("해당 기록 없음", systemImage: "checklist")
                }
            }
        }
    }
}

private struct DailyTextEditor: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)

                if text.isEmpty {
                    Text(prompt)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("입력 내용은 자동으로 저장됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct MonthCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let countsByDay: [Date: Int]
    let calendar: Calendar

    private var days: [TodoCalendarDay] {
        TodoCalendar(calendar: calendar).daysInMonth(containing: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("이전 달")

                Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("다음 달")

                Button("오늘") {
                    let today = Date()
                    displayedMonth = today
                    selectedDate = today
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(days, id: \.date) { day in
                    dayButton(day)
                }
            }
        }
        .frame(minWidth: 320)
    }

    private func dayButton(_ day: TodoCalendarDay) -> some View {
        let count = countsByDay[calendar.startOfDay(for: day.date), default: 0]
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = day.date
            if !day.isInDisplayedMonth {
                displayedMonth = day.date
            }
        } label: {
            VStack(spacing: 3) {
                Text(day.date.formatted(.dateTime.day()))
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(count == 0 ? " " : "\(count)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(
                isSelected ? Color.white : (day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(date: .long, time: .omitted))
        .accessibilityValue(count == 0 ? "할 일 없음" : "할 일 \(count)개")
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = nextMonth
    }
}
