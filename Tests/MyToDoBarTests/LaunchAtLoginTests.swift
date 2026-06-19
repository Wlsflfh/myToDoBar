import XCTest
@testable import MyToDoBarKit

final class LaunchAtLoginTests: XCTestCase {
    @MainActor
    func testDefaultsToDisabledFromSystemState() {
        let controller = FakeLaunchAtLoginController(status: .disabled)
        let model = LaunchAtLoginModel(controller: controller)

        XCTAssertFalse(model.isEnabled)
        XCTAssertNil(model.statusMessage)
    }

    @MainActor
    func testReflectsSuccessfulRegistration() {
        let controller = FakeLaunchAtLoginController(status: .disabled)
        let model = LaunchAtLoginModel(controller: controller)

        model.setEnabled(true)

        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(controller.status, .enabled)
    }

    @MainActor
    func testRollsBackWhenRegistrationFails() {
        let controller = FakeLaunchAtLoginController(status: .disabled, shouldFail: true)
        let model = LaunchAtLoginModel(controller: controller)

        model.setEnabled(true)

        XCTAssertFalse(model.isEnabled)
        XCTAssertNotNil(model.statusMessage)
    }
}

private final class FakeLaunchAtLoginController: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus
    let shouldFail: Bool

    init(status: LaunchAtLoginStatus, shouldFail: Bool = false) {
        self.status = status
        self.shouldFail = shouldFail
    }

    func setEnabled(_ enabled: Bool) throws {
        if shouldFail { throw TestError.failed }
        status = enabled ? .enabled : .disabled
    }

    private enum TestError: Error {
        case failed
    }
}
