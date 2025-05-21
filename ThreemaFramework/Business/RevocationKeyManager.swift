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

import Foundation
import ThreemaMacros

public class RevocationKeyManager {
    
    public static let shared = RevocationKeyManager()
    
    let businessInjector: BusinessInjectorProtocol
    let connector = ServerAPIConnector()

    // MARK: - Lifecycle

    private init(businessInjector: BusinessInjectorProtocol = BusinessInjector()) {
        self.businessInjector = businessInjector
    }
    
    // MARK: - Public func

    public func setPassword(_ password: String) {
        guard let myIdentityStore = businessInjector.myIdentityStore as? MyIdentityStore else {
            NotificationPresenterWrapper.shared.present(type: .revocationPasswordError)
            return
        }
        connector.setRevocationPassword(password, for: myIdentityStore) {
            myIdentityStore.revocationPasswordLastCheck = nil
            NotificationPresenterWrapper.shared.present(type: .revocationPasswordSuccess)
            NotificationCenter.default.post(name: NSNotification.Name(kRevocationPasswordUIRefresh), object: nil)
        } onError: { _ in
            NotificationPresenterWrapper.shared.present(type: .revocationPasswordError)
            NotificationCenter.default.post(name: NSNotification.Name(kRevocationPasswordUIRefresh), object: nil)
        }
    }
    
    public func checkPasswordSetDate(completion: @escaping () -> Void) {
        guard let myIdentityStore = businessInjector.myIdentityStore as? MyIdentityStore,
              myIdentityStore.revocationPasswordLastCheck == nil else {
            return
        }
        
        connector.checkRevocationPassword(for: myIdentityStore) { _, onDate in
            if let onDate {
                myIdentityStore.revocationPasswordLastCheck = Date.now
                myIdentityStore.revocationPasswordSetDate = onDate
            }
            else {
                myIdentityStore.revocationPasswordLastCheck = nil
                myIdentityStore.revocationPasswordSetDate = nil
            }
            completion()
        } onError: { _ in
            myIdentityStore.revocationPasswordLastCheck = nil
            myIdentityStore.revocationPasswordSetDate = nil
            completion()
        }
    }
}
