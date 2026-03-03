//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
