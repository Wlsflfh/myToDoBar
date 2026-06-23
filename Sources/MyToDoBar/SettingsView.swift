import SwiftUI
import MyToDoBarKit

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: LaunchAtLoginModel
    @ObservedObject var githubSettings: GitHubSettingsStore

    init(githubSettings: GitHubSettingsStore) {
        self.githubSettings = githubSettings
        _model = StateObject(wrappedValue: LaunchAtLoginModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("일반")
                    .font(.headline)

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

                Divider()

                Text("GitHub 메모 게시")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("저장소 URL")
                        .font(.subheadline.weight(.medium))
                    TextField("https://github.com/owner/repository.git", text: $githubSettings.repositoryURLInput)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("브랜치")
                        .font(.subheadline.weight(.medium))
                    TextField("main", text: $githubSettings.branchInput)
                        .textFieldStyle(.roundedBorder)
                    Text("비워두면 main · 게시 경로는 각 메모에서 설정")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("게시 설정 저장") {
                        githubSettings.saveConfiguration()
                    }
                    Spacer()
                    Text(savedDestination)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Fine-grained personal access token")
                        .font(.subheadline.weight(.medium))
                SecureField("Fine-grained personal access token", text: $githubSettings.tokenInput)
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("토큰 저장") {
                        githubSettings.save()
                    }
                    Button("토큰 삭제", role: .destructive) {
                        githubSettings.clear()
                    }
                    .disabled(!githubSettings.hasToken)
                    Spacer()
                    Text(githubSettings.hasToken ? "Keychain에 저장됨" : "토큰 없음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Fine-grained PAT에는 선택한 저장소의 Contents 읽기 및 쓰기 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusMessage = githubSettings.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 560)
        .onAppear(perform: model.refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
            }
        }
    }

    private var savedDestination: String {
        let configuration = githubSettings.configuration
        return configuration.branch
    }
}
