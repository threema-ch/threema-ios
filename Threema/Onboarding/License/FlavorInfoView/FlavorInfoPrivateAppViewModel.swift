import SwiftUI
import ThreemaMacros

struct FlavorInfoPrivateAppViewModel {
    
    let privateAppDescription = #localize("flavorinfo_privateappviewmodel_description")
    
    let downloadNow = #localize("flavorinfo_privateappviewmodel_load_now")
        
    let privateAppAppStoreLink: URL? = ThreemaURLProvider.privateDownloadAppStore
    
    func openPrivateAppStoreStoreLink() {
        if let url = privateAppAppStoreLink {
            UIApplication.shared.open(url)
        }
    }
}
