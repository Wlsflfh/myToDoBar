import MyToDoBarCore
import MyToDoBarKit
import SwiftUI

struct UpcomingSchedulesView: View {
    @ObservedObject var store: ScheduleStore
    let calendar: Calendar
    @State private var editingSchedule: ScheduleItem?
    @State private var isPresentingForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("다가오는 일정")
                    .font(.headline)

                Spacer()

                Button {
                    editingSchedule = nil
                    isPresentingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .help("일정 추가")
                .accessibilityLabel("일정 추가")
            }

            if let storageMessage = store.storageState.message {
                Label(storageMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let items = ScheduleCalendar().upcoming(from: store.items, after: context.date)

                    if items.isEmpty {
                        Text("예정된 일정이 없습니다")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 116)
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 7) {
                                ForEach(items) { item in
                                    scheduleButton(item, relativeTo: context.date)
                                }
                            }
                        }
                        .frame(height: 130)
                    }
                }
            }
        }
        .frame(height: 170, alignment: .top)
        .popover(isPresented: $isPresentingForm, arrowEdge: .trailing) {
            ScheduleFormView(
                store: store,
                calendar: calendar,
                schedule: editingSchedule,
                onDismiss: { isPresentingForm = false }
            )
            .id(editingSchedule?.id)
        }
    }

    private func scheduleButton(_ item: ScheduleItem, relativeTo now: Date) -> some View {
        Button {
            editingSchedule = item
            isPresentingForm = true
        } label: {
            HStack(spacing: 10) {
                Text(shortDate(item.deadline))
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                    .frame(width: 42, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("\(weekdayAndTime(item.deadline)) · \(remainingText(until: item.deadline, from: now))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(weekdayAndTime(item.deadline))")
    }

    private func shortDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0).\(components.day ?? 0)."
    }

    private func weekdayAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE HH:mm"
        return formatter.string(from: date)
    }

    private func remainingText(until deadline: Date, from now: Date) -> String {
        let seconds = max(0, deadline.timeIntervalSince(now))
        if seconds < 60 { return "1분 이내" }
        if seconds < 3_600 { return "\(Int(ceil(seconds / 60)))분 남음" }
        if seconds < 86_400 { return "\(Int(ceil(seconds / 3_600)))시간 남음" }
        return "\(max(1, Int(seconds / 86_400)))일 남음"
    }
}

private struct ScheduleFormView: View {
    @ObservedObject var store: ScheduleStore
    let calendar: Calendar
    let schedule: ScheduleItem?
    let onDismiss: () -> Void
    @State private var title: String
    @State private var deadline: Date
    @State private var errorMessage: String?
    @State private var isPresentingDatePicker = false

    init(
        store: ScheduleStore,
        calendar: Calendar,
        schedule: ScheduleItem?,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.calendar = calendar
        self.schedule = schedule
        self.onDismiss = onDismiss
        _title = State(initialValue: schedule?.title ?? "")
        _deadline = State(initialValue: schedule?.deadline ?? Date().addingTimeInterval(3_600))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(schedule == nil ? "새 일정" : "일정 편집")
                .font(.headline)

            TextField("일정 이름", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Text("날짜")
                    .frame(width: 38, alignment: .leading)

                Button(formattedDate) {
                    isPresentingDatePicker = true
                }
                .buttonStyle(.bordered)
                .frame(minWidth: 160, alignment: .leading)
                .popover(isPresented: $isPresentingDatePicker) {
                    VStack(spacing: 12) {
                        DatePicker("날짜", selection: $deadline, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                        HStack {
                            Spacer()
                            Button("완료") {
                                isPresentingDatePicker = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Text("시간")
                    .frame(width: 38, alignment: .leading)

                DatePicker("시간", selection: $deadline, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 170, alignment: .leading)

                Spacer()

                Button("하루 끝") {
                    setEndOfDay()
                }
                .help("선택한 날짜의 23:59로 설정")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let storageMessage = store.storageState.message {
                Text(storageMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if schedule != nil {
                    Button("삭제", role: .destructive) {
                        deleteSchedule()
                    }
                }

                Spacer()

                Button("취소", action: onDismiss)
                Button("저장", action: saveSchedule)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private var formattedDate: String {
        let components = calendar.dateComponents([.year, .month, .day], from: deadline)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private func setEndOfDay() {
        guard let endOfDay = ScheduleCalendar().endOfDay(for: deadline, calendar: calendar) else { return }
        deadline = endOfDay
    }

    private func saveSchedule() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "일정 이름을 입력해 주세요."
            return
        }
        guard deadline > Date() else {
            errorMessage = "현재보다 이후 시간을 선택해 주세요."
            return
        }

        let succeeded: Bool
        if let schedule {
            succeeded = store.update(id: schedule.id, title: trimmed, deadline: deadline)
        } else {
            succeeded = store.add(title: trimmed, deadline: deadline) != nil
        }

        if succeeded {
            onDismiss()
        } else {
            errorMessage = store.storageState.message ?? "일정을 저장하지 못했습니다."
        }
    }

    private func deleteSchedule() {
        guard let schedule else { return }
        if store.delete(id: schedule.id) {
            onDismiss()
        } else {
            errorMessage = store.storageState.message ?? "일정을 삭제하지 못했습니다."
        }
    }
}
