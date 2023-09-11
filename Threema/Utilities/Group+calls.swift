//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import Foundation
import GroupCalls

extension Group {
    
    /// Start a group call. It will check if group calls are enabled.
    /// - Parameter settingsStore: SettingsStore
    func startGroupCall(settingsStore: SettingsStoreProtocol) {
        guard ThreemaEnvironment.groupCalls, settingsStore.enableThreemaGroupCalls else {
            assertionFailure()
            return
        }
        
        Task { @MainActor in
            do {
                let viewModel = try await GlobalGroupCallsManagerSingleton.shared.startGroupCall(
                    in: conversation,
                    with: MyIdentityStore.shared().identity
                )
                await GlobalGroupCallsManagerSingleton.shared.groupCallManager.set(uiDelegate: self)
                let groupCallViewController = GlobalGroupCallsManagerSingleton.shared
                    .groupCallViewController(for: viewModel)
                AppDelegate.shared().currentTopViewController().present(groupCallViewController, animated: true)
            }
            catch {
                guard let groupCallError = error as? GroupCallErrorProtocol else {
                    return
                }
                // TODO: IOS-3743 Graceful Error Handling
                UIAlertTemplate.showAlert(
                    owner: AppDelegate.shared().currentTopViewController(),
                    title: BundleUtil.localizedString(forKey: groupCallError.alertTitleKey),
                    message: BundleUtil.localizedString(forKey: groupCallError.alertMessageKey)
                )
            }
        }
    }
}

// MARK: - Group + GroupCallManagerUIDelegate

extension Group: GroupCallManagerUIDelegate {
    @MainActor
    public func showViewController(for viewModel: GroupCalls.GroupCallViewModel) {
        let groupCallViewController = GlobalGroupCallsManagerSingleton.shared
            .groupCallViewController(for: viewModel)
        AppDelegate.shared().currentTopViewController().present(groupCallViewController, animated: true)
    }
}
