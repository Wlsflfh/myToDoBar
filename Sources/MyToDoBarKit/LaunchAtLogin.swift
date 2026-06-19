import Combine
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

private struct SystemLaunchAtLoginController: LaunchAtLoginControlling {
    private var service: SMAppService { .mainApp }

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}

@MainActor
public final class LaunchAtLoginModel: ObservableObject {
    @Published public private(set) var isEnabled = false
    @Published public private(set) var statusMessage: String?

    private let controller: any LaunchAtLoginControlling

    public convenience init() {
        self.init(controller: SystemLaunchAtLoginController())
    }

    init(controller: any LaunchAtLoginControlling) {
        self.controller = controller
        refresh()
    }

    public func setEnabled(_ enabled: Bool) {
        do {
            try controller.setEnabled(enabled)
            refresh()
        } catch {
            refresh()
            statusMessage = "로그인 항목을 변경하지 못했습니다. 시스템 설정을 확인해 주세요."
        }
    }

    public func refresh() {
        switch controller.status {
        case .disabled:
            isEnabled = false
            statusMessage = nil
        case .enabled:
            isEnabled = true
            statusMessage = nil
        case .requiresApproval:
            isEnabled = false
            statusMessage = "시스템 설정 > 일반 > 로그인 항목에서 MyToDoBar를 허용해 주세요."
        case .unavailable:
            isEnabled = false
            statusMessage = "로그인 항목은 앱 번들로 실행할 때 설정할 수 있습니다."
        }
    }
}
