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
