import MyToDoBarCore
import MyToDoBarKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: TodoStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @FocusState private var isInputFocused: Bool
    @State private var draft = ""
    @State private var isAddingTodo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(headerDate)
                    .font(.title2.bold())

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isAddingTodo.toggle()
                    }
                    if isAddingTodo {
                        isInputFocused = true
                    }
                } label: {
                    Image(systemName: isAddingTodo ? "xmark" : "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAddingTodo ? "입력 닫기" : "할 일 추가")
            }

            if isAddingTodo {
                TextField("할 일 추가", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit(addTodo)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let storageError = store.storageState.message {
                VStack(alignment: .leading, spacing: 6) {
                    Label(storageError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("저장소 다시 읽기") {
                        store.reload()
                    }
                    .font(.caption)
                }
            }

            Divider()

            if store.todayItems.isEmpty {
                ContentUnavailableView(
                    "오늘의 할 일이 없습니다",
                    systemImage: "checkmark.circle",
                    description: Text("생각나는 일을 바로 적어보세요.")
                )
                .frame(minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.todayItems) { item in
                            TodoRow(item: item) {
                                store.toggle(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider()

            HStack {
                Button("전체 보기") {
                    openWindow(id: "history")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Spacer()

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("설정 열기")
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func addTodo() {
        if store.add(title: draft) {
            draft = ""
            isAddingTodo = false
        }
    }

    private var headerDate: String {
        let components = store.calendar.dateComponents([.year, .month, .day], from: store.currentDate)
        return String(
            format: "%02d.%02d.%02d",
            (components.year ?? 0) % 100,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "미완료로 변경" : "완료로 변경")
            .accessibilityValue(item.isCompleted ? "완료" : "미완료")

            Text(item.title)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .opacity(item.isCompleted ? 0.55 : 1)
    }
}
