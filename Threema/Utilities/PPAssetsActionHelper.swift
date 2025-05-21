//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2025 Threema GmbH
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

import CoreLocation
import Foundation
import Photos
import ThreemaMacros
import UIKit

@objc public protocol PPAssetsActionHelperDelegate: AnyObject {
    /// Called when a user dismisses a picker by tapping cancel or background.
    /// Implementation is optional.
    /// - Parameter picker: Picker Controller that was dismissed.
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper)
    
    /// Called when a user selects previews and presses send button.
    /// Assets Picker is not dismissed automatically when the delegate method is called.
    /// Implementation is optional.
    /// - Parameters:
    /// - picker: Current picker controller.
    /// - assets: Assets that were selected with Preview Picker.
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /// Called when a user click the own option
    /// Assets Picker is not dismissed automatically when the delegate method is called.
    /// Implementation is optional.
    /// - Parameter picker: Picker Controller that was dismissed.
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /// Called when a user click the own snap button
    /// Assets Picker is not dismissed automatically when the delegate method is called.
    /// Implementation is optional.
    /// - Parameter picker: Picker Controller that was dismissed.
    /// - assets: Assets that were selected with Preview Picker.
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any])
    
    /// Called when a user click the live camera cell
    /// Assets Picker is not dismissed automatically when the delegate method is called.
    /// Implementation is optional.
    /// - Parameter picker: Picker Controller.
    func assetsActionHelperDidSelectLiveCameraCell(_ picker: PPAssetsActionHelper)
    
    func assetsActionHelperDidSelectLocation(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper)
    func assetsActionHelperDidSelectScanDocument(_ picker: PPAssetsActionHelper)

    var conversationIsDistributionList: Bool { get }
}

/// Default implementation for delegate methods to make them optional.
extension PPAssetsActionHelperDelegate {
    func assetsActionHelperDidCancel(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelper(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) { }
    func assetActionHelperDidSelectOwnOption(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) { }
    func assetsActionHelperDidSelectOwnSnapButton(_ picker: PPAssetsActionHelper, didFinishPicking assets: [Any]) { }
    func assetsActionHelperDidSelectLiveCameraCell(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelperDiassetsPickerDidSelectLiveCameraCelldSelectLocation(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelperDidSelectRecordAudio(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelperDidSelectCreateBallot(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelperDidSelectShareFile(_ picker: PPAssetsActionHelper) { }
    func assetsActionHelperDidSelectScanDocument(_ picker: PPAssetsActionHelper) { }
}

public class PPAssetsActionHelper: NSObject {
    
    @objc open weak var delegate: PPAssetsActionHelperDelegate?
        
    override public required init() {
        super.init()
    }
    
    enum Heights: CGFloat {
        case Inches_3_5 = 480
        case Inches_4 = 568
        case Inches_4_7 = 667
        case Inches_5_5 = 736
    }
    
    func isPhone() -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    func isSizeOrLarger(height: Heights) -> Bool {
        UIScreen.main.bounds.size.height >= height.rawValue
    }
    
    func IS_4_7_INCHES_OR_LARGER() -> Bool {
        isPhone() && isSizeOrLarger(height: .Inches_4_7)
    }
    
    @objc public func buildAction() -> PPAssetsActionController {
        var options = [PPOption]()
        
        let shareLocationImage = UIImage(
            systemName: "mappin.and.ellipse",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.tintColor, renderingMode: .alwaysOriginal)
        let shareLocation = PPOption(
            withTitle: #localize("send_location"),
            withIcon: shareLocationImage
        ) {
            self.delegate?.assetsActionHelperDidSelectLocation(self)
        }
        options.append(shareLocation)
        
        let ballotImage = UIImage(
            systemName: "chart.pie.fill",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.tintColor, renderingMode: .alwaysOriginal)
        let ballotCreate = PPOption(
            withTitle: #localize("ballot_create"),
            withIcon: ballotImage
        ) {
            self.delegate?.assetsActionHelperDidSelectCreateBallot(self)
        }
        
        if !(delegate?.conversationIsDistributionList ?? false) {
            options.append(ballotCreate)
        }
        
        let shareImage = UIImage(
            systemName: "doc.fill",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.tintColor, renderingMode: .alwaysOriginal)
        let shareFile = PPOption(
            withTitle: #localize("share_file"),
            withIcon: shareImage
        ) {
            self.delegate?.assetsActionHelperDidSelectShareFile(self)
        }
        options.append(shareFile)
        
        let scanner = PPOption(
            withTitle: #localize("scan_document"),
            withIcon: UIImage(systemName: "doc.viewfinder.fill")
        ) {
            self.delegate?.assetsActionHelperDidSelectScanDocument(self)
        }
        options.append(scanner)

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
        
        if Colors.theme == .dark {
            config.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.9)
        }
        else {
            config.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        }
        
        config.maxSelectableAssets = 10
        
        config.useOwnSnapButton = true
        config.ownSnapButtonText = #localize("choose_existing")
        config.ownSnapButtonIcon = UIImage(
            systemName: "photo.fill",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.tintColor, renderingMode: .alwaysOriginal)

        config.previewReplacementText = #localize("take_photo_or_video")
        config.previewReplacementIcon = UIImage(
            systemName: "camera.fill",
            withConfiguration: UIImage.SymbolConfiguration(textStyle: .body)
        )?
            .withTintColor(.tintColor, renderingMode: .alwaysOriginal)
        
        config.tintColor = .tintColor
        config.tableBackground = Colors.backgroundNavigationController
        
        config.showAdditionalOptionWhenAssetIsSelected = true
        config.additionalOptionText = #localize("send_immediately_text")
        
        let assetsPicker = PPAssetsActionController(with: options, aConfig: config)
        assetsPicker.delegate = self
        return assetsPicker
    }
}

// MARK: - PPAssetsActionControllerDelegate

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
    
    public func assetsPicker(_ picker: PPAssetsActionController, didSnapImage image: UIImage) { }
    
    public func assetsPicker(_ picker: PPAssetsActionController, didSnapVideo videoURL: URL) { }
    
    public func assetsPickerDidSelectOwnOption(
        _ picker: PPAssetsActionController,
        didFinishPicking media: [MediaProvider]
    ) {
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
    
    public func assetsPickerDidSelectOwnSnapButton(
        _ picker: PPAssetsActionController,
        didFinishPicking media: [MediaProvider]
    ) {
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
