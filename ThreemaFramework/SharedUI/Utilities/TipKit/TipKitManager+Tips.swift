//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import TipKit

@available(iOSApplicationExtension 17.0, *)
extension TipKitManager {
    
    /// Tip shown when type icon is show for first time
    public struct ThreemaTypeTip: Tip {
        public var title: Text {
            if LicenseStore.requiresLicenseKey() {
                Text("contact_threema_title".localized)
            }
            else {
                Text("contact_threema_work_title".localized)
            }
        }

        public var message: Text? {
            if LicenseStore.requiresLicenseKey() {
                Text("contact_threema_info".localized)
            }
            else {
                Text("contact_threema_work_info".localized)
            }
        }

        public var image: Image? {
            Image(uiImage: ThreemaUtility.otherThreemaTypeIcon)
        }

        public init() { }
    }
}
