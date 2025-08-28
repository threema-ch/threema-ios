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

import SwiftUI
import ThreemaMacros

struct FlavorInfoBusinessAppViewModel {
    let loginNowText = #localize("flavorinfo_businessappviewmodel_login_now")
    
    let threemaUnusedText = String.localizedStringWithFormat(
        #localize("flavorinfo_businessappviewmodel_app_unused"),
        TargetManager.appName
    )
    
    let moreInformationText = #localize("flavorinfo_businessappviewmodel_more_information")
        
    let promotionText =
        if TargetManager.isWork {
            #localize("flavorinfo_businessappviewmodel_work_promotion")
        }
        else {
            #localize("flavorinfo_businessappviewmodel_onprem_promotion")
        }
    
    let descriptionText =
        if TargetManager.isWork {
            #localize("flavorinfo_businessappviewmodel_work_description")
        }
        else {
            #localize("flavorinfo_businessappviewmodel_onprem_description")
        }
    
    let flavorInfoURL: URL? =
        if TargetManager.isWork {
            ThreemaURLProvider.flavorInfoWork
        }
        else {
            ThreemaURLProvider
                .flavorInfoOnPrem
        }
    
    func openWebsiteForFlavorInfo() {
        if let url = flavorInfoURL {
            UIApplication.shared.open(url)
        }
    }
}
