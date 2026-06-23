import Darwin
import ServiceManagement
import SwiftUI
import MyToDoBarKit

@main
struct MyToDoBarApp: App {
    @StateObject private var store = TodoStore()
    @StateObject private var dailyLogStore = DailyLogStore()
    @StateObject private var githubSettings = GitHubSettingsStore()

    init() {
        guard CommandLine.arguments.contains("--verify-launch-at-login") else { return }
        Self.verifyLaunchAtLogin()
    }

    var body: some Scene {
        MenuBarExtra("MyToDoBar", systemImage: "checklist") {
            MenuBarView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("전체 보기", id: "history") {
            HistoryView(
                store: store,
                dailyLogStore: dailyLogStore,
                githubSettings: githubSettings
            )
        }
        .defaultSize(width: 840, height: 620)

        Settings {
            SettingsView(githubSettings: githubSettings)
        }
    }

    private static func verifyLaunchAtLogin() -> Never {
        let service = SMAppService.mainApp
        guard service.status != .enabled, service.status != .requiresApproval else {
            finishDiagnostic(
                "launch-at-login diagnostic refused: existing status is \(service.status.rawValue)",
                code: EXIT_FAILURE
            )
        }

        do {
            try service.register()
            let registeredStatus = service.status
            try service.unregister()
            let unregisteredStatus = service.status
            finishDiagnostic(
                "registered=\(registeredStatus.rawValue) unregistered=\(unregisteredStatus.rawValue)",
                code: unregisteredStatus == .notRegistered ? EXIT_SUCCESS : EXIT_FAILURE
            )
        } catch {
            try? service.unregister()
            finishDiagnostic("launch-at-login diagnostic failed: \(error.localizedDescription)", code: EXIT_FAILURE)
        }
    }

    private static func finishDiagnostic(_ message: String, code: Int32) -> Never {
        let outputURL = URL(fileURLWithPath: "/tmp/mytodobar-launch-at-login-diagnostic.txt")
        do {
            try message.write(to: outputURL, atomically: true, encoding: .utf8)
        } catch {
            print("failed to write diagnostic output: \(error.localizedDescription)")
        }
        print(message)
        exit(code)
    }
}
