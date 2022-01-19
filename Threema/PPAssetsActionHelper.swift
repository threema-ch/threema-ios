//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2022 Threema GmbH
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
import UIKit
import CoreLocation
import Photos

@objc public protocol PPAssetsActionHelperDelegate: class {
    /**
     Called when a user dismisses a picker by tapping cancel or background.
     Implementation is optional.
     - Parameter picker: Picker Controller that was dismissed.
     */
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper)
    
    /**
     Called when a user selects previews and presses send button.
     Assets Picker is not dismissed automatically when the delegate method is called.
     Implementation is optional.
     - Parameters:
     - picker: Current picker controller.
     - assets: Assets that were selected with Preview Picker.
     */
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /**
     Called when a user click the own option
     Assets Picker is not dismissed automatically when the delegate method is called.
     Implementation is optional.
     - Parameter picker: Picker Controller that was dismissed.
     */
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /**
     Called when a user click the own snap button
     Assets Picker is not dismissed automatically when the delegate method is called.
     Implementation is optional.
     - Parameter picker: Picker Controller that was dismissed.
     - assets: Assets that were selected with Preview Picker.
     */
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /**
     Called when a user click the live camera cell
     Assets Picker is not dismissed automatically when the delegate method is called.
     Implementation is optional.
     - Parameter picker: Picker Controller.
     */
    func assetsActionHelperDidSelectLiveCameraCell(_ picker: PPAssetsActionHelper)
    
    func assetsActionHelperDidSelectLocation(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper)
}


/**
 Default implementation for delegate methods to make them optional.
 */
extension PPAssetsActionHelperDelegate {
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper) {}
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {}
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {}
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) {}
    func assetsActionHelperDidSelectLiveCameraCell(_ picker: PPAssetsActionHelper) {}
    func assetsActionHelperDiassetsPickerDidSelectLiveCameraCelldSelectLocation(_ picker: PPAssetsActionHelper) {}
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper) {}
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper) {}
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper) {}
}

public class PPAssetsActionHelper: NSObject {
    
    @objc open weak var delegate: PPAssetsActionHelperDelegate?
        
    required public override init() {
        super.init()
    }
    
    enum Heights: CGFloat {
        case Inches_3_5 = 480
        case Inches_4 = 568
        case Inches_4_7 = 667
        case Inches_5_5 = 736
    }
    
    internal func isPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    internal func isSizeOrLarger(height: Heights) -> Bool {
        return UIScreen.main.bounds.size.height >= height.rawValue
    }
    
    internal func IS_4_7_INCHES_OR_LARGER() -> Bool {
        return isPhone() && isSizeOrLarger(height: .Inches_4_7)
    }
    
    @objc public func buildAction() -> PPAssetsActionController {
        var options = Array<PPOption>()
        
        if CLLocationManager.locationServicesEnabled() {
            let shareLocation = PPOption(withTitle: NSLocalizedString("share_location", comment: ""), withIcon: UIImage(named: "ActionLocation", in: Colors.main())) {
                self.delegate?.assetsActionHelperDidSelectLocation(self)
            }
            options.append(shareLocation)
        }
        
        if PlayRecordAudioViewController.canRecordAudio() {
            let recordAudio = PPOption(withTitle: NSLocalizedString("record_audio", comment: ""), withIcon: UIImage(named: "ActionMicrophone", in: Colors.main())) {
                self.delegate?.assetsActionHelperDidSelectRecordAudio(self)
            }
            options.append(recordAudio)
        }
        
        let ballotCreate = PPOption(withTitle: NSLocalizedString("ballot_create", tableName: "Ballot", bundle: Bundle.main, value: "", comment: ""), withIcon: UIImage(named: "ActionBallot", in: Colors.main())) {
            self.delegate?.assetsActionHelperDidSelectCreateBallot(self)
        }
        options.append(ballotCreate)

        let shareFile = PPOption(withTitle: NSLocalizedString("share_file", comment: ""), withIcon: UIImage(named: "ActionFile", in: Colors.main())) {
                self.delegate?.assetsActionHelperDidSelectShareFile(self)
            }
            options.append(shareFile)

        var config = PPAssetsActionConfig()
        config.textAlignment = .left
        config.showOptionsWhenAssetIsSelected = false
        
        config.showLiveCameraCell = true
        config.showVideos = true
    
        config.showGalleryPreview = UserSettings.shared().showGalleryPreview
        
        config.assetsPreviewExpandedHeight = 260.0
        config.inset = 10.0
        config.cornerRadius = 10.0
        config.sectionSpacing = 8.0
        
        config.fetchLimit = Int(UserSettings.shared().previewLimit)
        
        config.buttonHeight = IS_4_7_INCHES_OR_LARGER() ? 50.0 : 42.0
        
        config.backgroundColor = UIColor(red:0.0 , green: 0.0, blue: 0.0, alpha: 0.5)
        config.maxSelectableAssets = 10
        
        config.useOwnSnapButton = true
        config.ownSnapButtonText = NSLocalizedString("choose_existing", comment: "")
        config.ownSnapButtonIcon = UIImage(named: "ActionPhoto", in: Colors.main())

        config.previewReplacementText = NSLocalizedString("take_photo_or_video", comment: "")
        config.previewReplacementIcon = UIImage(named: "ActionCamera", in: Colors.main())
        
        config.tintColor = Colors.main()
        config.tableBackground = Colors.background()
        
        config.showAdditionalOptionWhenAssetIsSelected = true
        config.additionalOptionText = BundleUtil.localizedString(forKey: "send_immediately_text")
        
        let assetsPicker = PPAssetsActionController(with: options, aConfig: config)
        assetsPicker.delegate = self
        return assetsPicker
    }
}

extension PPAssetsActionHelper: PPAssetsActionControllerDelegate {
    public func assetsPickerDidCancel(_ picker: PPAssetsActionController) {
        delegate?.assetsActionHelperDidCancel(self)
        print("assetsPickerDidCancel")
    }
    
    public func assetsPicker(_ picker: PPAssetsActionController, didFinishPicking media: [MediaProvider]) {
        var mediaArray = [Any]()
        
        for m in media {
            if m.image() != nil {
                mediaArray.append(m.image()!)
            }
            if m.video() != nil {
                mediaArray.append(m.video()!)
            }
            if m.phasset() != nil {
                mediaArray.append(m.phasset()!)
            }
        }
        
        delegate?.assetsActionHelper(self, didFinishPicking: mediaArray)
        print("assetsPicker didFinishPicking with \(media)")
    }
    
    public func assetsPicker(_ picker: PPAssetsActionController, didSnapImage image: UIImage) {
    }
    
    public func assetsPicker(_ picker: PPAssetsActionController, didSnapVideo videoURL: URL) {
    }
    
    public func assetsPickerDidSelectOwnOption(_ picker: PPAssetsActionController, didFinishPicking media: [MediaProvider]) {
        var mediaArray = [Any]()
        
        for m in media {
            if m.image() != nil {
                mediaArray.append(m.image()!)
            }
            if m.video() != nil {
                mediaArray.append(m.video()!)
            }
            if m.phasset() != nil {
                mediaArray.append(m.phasset()!)
            }
        }
        
        delegate?.assetActionHelperDidSelectOwnOption(self, didFinishPicking: mediaArray)
        print("assetsPicker didSelectOwnOption")
    }
    
    public func assetsPickerDidSelectOwnSnapButton(_ picker: PPAssetsActionController, didFinishPicking media: [MediaProvider]) {
        var mediaArray = [Any]()
        
        for m in media {
            if m.image() != nil {
                mediaArray.append(m.image()!)
            }
            if m.video() != nil {
                mediaArray.append(m.video()!)
            }
            if m.phasset() != nil {
                mediaArray.append(m.phasset()!)
            }
        }
        
        delegate?.assetsActionHelperDidSelectOwnSnapButton(self, didFinishPicking: mediaArray)
        print("assetsPicker didSelectOwnSnapButton")
    }
    
    public func assetsPickerDidSelectLiveCameraCell(_ picker: PPAssetsActionController) {
        delegate?.assetsActionHelperDidSelectLiveCameraCell(self)
    }
}
