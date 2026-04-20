import Testing
@testable import ThreemaFramework

struct AppSetupStateTests {

    @Test("Test all cases of AppSetupState", arguments: AppSetupState.allCases.map(\.rawValue))
    func testAllStates(_ rawValue: Int) async throws {
        AppGroup.setGroupID("group.ch.threema")

        let state = AppSetupState(rawValue: rawValue)

        let testMdmSetupInit: () throws -> Void = {
            _ = MDMSetup(appSetupStateRawValue: rawValue)
        }

        switch state {
        case .notSetup:
            try testMdmSetupInit()
        case .identityAdded:
            try testMdmSetupInit()
        case .identitySetupComplete:
            try testMdmSetupInit()
        case .complete:
            break
        case .none:
            Issue.record("Invalid raw value for AppSetupState")
        }
    }
}
