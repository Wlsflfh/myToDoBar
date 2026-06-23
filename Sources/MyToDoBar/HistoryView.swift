import MyToDoBarCore
import MyToDoBarKit
import SwiftUI

private enum TodoFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case incomplete = "미완료"
    case completed = "완료"

    var id: Self { self }
}

struct HistoryView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var dailyLogStore: DailyLogStore
    @ObservedObject var githubSettings: GitHubSettingsStore
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var selectedNoteID: UUID?
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
                RecordTabs(
                    notes: dailyLogStore.notes(on: selectedDate),
                    selectedNoteID: $selectedNoteID,
                    addNote: {
                        selectedNoteID = dailyLogStore.addNote(on: selectedDate)?.id
                    }
                )

                Divider()

                if let selectedNoteID,
                   dailyLogStore.notes(on: selectedDate).contains(where: { $0.id == selectedNoteID }) {
                    DailyNoteEditor(
                        store: dailyLogStore,
                        githubSettings: githubSettings,
                        noteID: selectedNoteID,
                        onDelete: { self.selectedNoteID = nil }
                    )
                } else {
                    TodoHistoryDetail(store: store, date: selectedDate, filter: $todoFilter)
                }
            }
            .navigationTitle(selectedDate.formatted(date: .long, time: .omitted))
            .onChange(of: selectedDate) {
                selectedNoteID = nil
            }
        }
    }
}

private struct RecordTabs: View {
    let notes: [DailyNote]
    @Binding var selectedNoteID: UUID?
    let addNote: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                tabButton("할 일", id: nil)

                ForEach(notes) { note in
                    tabButton(note.title.isEmpty ? "제목 없음" : note.title, id: note.id)
                }

                Button(action: addNote) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("메모 추가")
                .accessibilityLabel("메모 추가")
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tabButton(_ title: String, id: UUID?) -> some View {
        Button(title) {
            selectedNoteID = id
        }
        .buttonStyle(.borderedProminent)
        .tint(selectedNoteID == id ? Color.accentColor : Color.secondary.opacity(0.35))
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
                    Button {
                        store.toggle(item)
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? Color.secondary : Color.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isCompleted ? "미완료로 변경" : "완료로 변경")

                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    Spacer()
                    Text(item.isCompleted ? "완료" : "미완료")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        store.delete(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("할 일 삭제")
                    .accessibilityLabel("할 일 삭제")
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("해당 기록 없음", systemImage: "checklist")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DailyNoteEditor: View {
    @ObservedObject var store: DailyLogStore
    @ObservedObject var githubSettings: GitHubSettingsStore
    let noteID: UUID
    let onDelete: () -> Void
    @State private var publishMessage: String?
    @State private var isPublishing = false
    @FocusState private var isTextEditorFocused: Bool

    private let publisher = GitHubPublisher()

    private var note: DailyNote? {
        store.notes.first { $0.id == noteID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("메모 제목", text: Binding(
                    get: { note?.title ?? "" },
                    set: { store.setTitle($0, for: noteID) }
                ))
                .font(.title3.bold())
                .textFieldStyle(.plain)

                Button {
                    publish()
                } label: {
                    if isPublishing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("GitHub 푸시", systemImage: "arrow.up.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPublishing)

                Button(role: .destructive) {
                    guard store.deleteNote(id: noteID) else { return }
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("메모 삭제")
                .accessibilityLabel("메모 삭제")
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                TextField("게시 경로 (비워두면 저장소 루트)", text: Binding(
                    get: { note.map(effectivePublishPath) ?? "" },
                    set: { store.setPublishPath($0, for: noteID) }
                ))
                .textFieldStyle(.roundedBorder)
                .help("예: contents/java")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: { note?.text ?? "" },
                    set: { store.setText($0, for: noteID) }
                ))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($isTextEditorFocused)

                if note?.text.isEmpty != false, !isTextEditorFocused {
                    Text("내용을 입력하세요.")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))

            if let publishMessage {
                Text(publishMessage)
                    .font(.caption)
                    .foregroundStyle(publishMessage.hasPrefix("완료") ? Color.green : Color.red)
            } else if let errorMessage = store.errorMessage {
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

    private func publish() {
        guard let note else { return }
        guard let token = githubSettings.token else {
            publishMessage = GitHubPublishError.missingToken.localizedDescription
            return
        }

        isPublishing = true
        publishMessage = nil
        Task {
            do {
                var configuration = githubSettings.configuration
                configuration.path = effectivePublishPath(note)
                let result = try await publisher.publish(
                    note: note,
                    token: token,
                    configuration: configuration
                )
                guard store.setRemote(
                    path: result.path,
                    sha: result.sha,
                    repository: result.repository,
                    branch: result.branch,
                    for: noteID
                ) else {
                    publishMessage = "GitHub에는 업로드했지만 로컬 게시 정보를 저장하지 못했습니다."
                    isPublishing = false
                    return
                }
                publishMessage = "완료: \(result.path)"
            } catch {
                publishMessage = error.localizedDescription
            }
            isPublishing = false
        }
    }

    private func effectivePublishPath(_ note: DailyNote) -> String {
        if let publishPath = note.publishPath {
            return publishPath
        }
        guard let remotePath = note.remotePath,
              let separator = remotePath.lastIndex(of: "/") else {
            return ""
        }
        return String(remotePath[..<separator])
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
                .buttonStyle(.borderedProminent)
                .tint(.blue)
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
                Text("\(calendar.component(.day, from: day.date))")
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
