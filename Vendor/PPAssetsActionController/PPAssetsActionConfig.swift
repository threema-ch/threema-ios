// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema AG and licensed under the AGPLv3.

// Copyright (c) 2016 Pavel Pantus <pantusp@gmail.com>
// See Resources/License.html for original license

import UIKit

/**
 Configuration of Assets Action Controller.
 */
public struct PPAssetsActionConfig {
    
    /// Tint Color. System's by default.
    public var tintColor = UIView().tintColor
    
    /// Font to be used on buttons.
    public var font = UIFont.systemFont(ofSize: 19.0)
    
    /// Text alignement to be used on buttons.
    public var textAlignment = NSTextAlignment.center
    
    /**
     Indicates whether Assets Action Controller should ask for photo permissions in case
     they were not previously granted.
     If false, no room will be allocated for Assets View Controller.
     */
    public var askPhotoPermissions = true
    
    /// Regular (folded) height of Assets View Controller.
    public var assetsPreviewRegularHeight: CGFloat = 150.0
    
    /// Expanded height of Assets View Controller.
    public var assetsPreviewExpandedHeight: CGFloat = 220.0
    
    /// Left, Right and Bottom insets of Assets Action Controller.
    public var inset: CGFloat = 16.0
    
    /// Spacing between Cancel and option buttons.
    public var sectionSpacing: CGFloat = 16.0
    
    /// Background color of Assets View Controller.
    public var backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.35)
    
    /// In and Out animation duration.
    public var animationDuration: TimeInterval = 0.5
    
    /// Max selectable assets
    public var maxSelectableAssets: Int = 0
    
    /// Height of each button (Options and Cancel).
    public var buttonHeight: CGFloat = 50.0
    
    /// If enabled shows live camera view as a first cell.
    public var showLiveCameraCell = true
    
    /// If enabled shows videos in Assets Collection Controller and autoplays them.
    public var showVideos = true
    
    /// If enabled shows all options when a asset is selected
    public var showOptionsWhenAssetIsSelected = true
    
    /// If enabled it will add a additional button if showOptionsWhenAssetIsSelected is disabled
    public var showAdditionalOptionWhenAssetIsSelected = false
    
    /// Title for additional option button
    public var additionalOptionText:String? = nil
    
    /// Use snap button as custom button
    public var useOwnSnapButton = false
    
    /// Title for snap button
    public var ownSnapButtonText:String? = nil
    public var ownSnapButtonIcon:UIImage? = nil
    
    /// Corner radius
    public var cornerRadius: CGFloat = 5.0
    
    /// Fetch limit
    public var fetchLimit: Int = 100
    
    public var showGalleryPreview:Bool = false
    
    public var previewReplacementText: String = NSLocalizedString("take_photo_or_video", comment: "")
    
    public var previewReplacementIcon: UIImage? = nil
    
    /***** BEGIN THREEMA MODIFICATION: tableBackground *********/
    public var tableBackground: UIColor? = nil
    /***** END THREEMA MODIFICATION: tableBackground *********/

    public init() {}
    
    @available(*, deprecated, message: "Use showReplacementOptionInLandscape(traitCollection:) instead")
    public func showReplacementOptionInLandscape() -> Bool {
        showReplacementOptionInLandscape(traitCollection: UITraitCollection.current)
    }
    
    public func showReplacementOptionInLandscape(traitCollection: UITraitCollection) -> Bool {
        if UIImagePickerController.isSourceTypeAvailable(.camera) && ((isLandscape(traitCollection: traitCollection) && UIDevice.current.userInterfaceIdiom != .pad) || UIAccessibility.isVoiceOverRunning || !showGalleryPreview) {
            return true
        }
        return false
    }
    
    @available(*, deprecated, message: "Use isLandscape(traitCollection:) instead")
    public func isLandscape() -> Bool {
        isLandscape(traitCollection: UITraitCollection.current)
    }
    
    /// Whether the vertical space is constrained (e.g. iPhone in landscape), which leaves no room for the gallery preview
    public func isLandscape(traitCollection: UITraitCollection) -> Bool {
        traitCollection.verticalSizeClass == .compact
    }
}
