import Foundation
import ThreemaMacros

extension LocationMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        if let poiName {
            poiName
        }
        else if let poiAddress {
            poiAddress
        }
        else {
            #localize("location")
        }
    }
    
    public var previewSymbolName: String? {
        "mappin.circle.fill"
    }
}
