import SwiftUI
import MyToDoBarKit

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: LaunchAtLoginModel

    init() {
        _model = StateObject(wrappedValue: LaunchAtLoginModel())
    }

    var body: some View {
        Form {
            Toggle(
                "로그인 시 자동 실행",
                isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                )
            )

            if let statusMessage = model.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("기본값은 꺼짐입니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear(perform: model.refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
            }
        }
    }
}
