import UIKit

final class MediaPreviewCarouselContainerView: UIView {
    var carouselAccessibilityElement: MediaPreviewCarouselAccessibilityElement?
    weak var delegate: MediaPreviewViewController?
    var currentImage: MediaPreviewItem?
    var index = 0
    
    override var accessibilityElements: [Any]? {
        get {
            var carAccessibilityElements: [Any]
            
            let carAccessibilityElement: MediaPreviewCarouselAccessibilityElement
            if let theCarouselAccessibilityElement = carouselAccessibilityElement {
                carAccessibilityElement = theCarouselAccessibilityElement
            }
            else {
                carAccessibilityElement = MediaPreviewCarouselAccessibilityElement(
                    accessibilityContainer: self,
                    currentMediaItem: delegate?.getCurrentlyVisibleItem()
                )
                index += 1
                
                carAccessibilityElement.accessibilityFrameInContainerSpace = frame
            }
            
            carAccessibilityElements = [carAccessibilityElement]
            carouselAccessibilityElement = carAccessibilityElement
            
            return carAccessibilityElements
        }
        set { }
    }
}
