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

import FileUtility
import ThreemaFramework
import ThreemaMacros

struct PreviewUnavailableViewModel {
    private let fileMessageEntity: FileMessageEntity
    private let mdmManager: MDMSetup

    var thumbnailSymbolName: String {
        "document.fill"
    }
    
    var fileName: String? {
        fileMessageEntity.fileName
    }
    
    var fileSizeText: String? {
        guard let size = fileMessageEntity.fileSize?.floatValue else {
            return nil
        }
        return ThreemaUtility.formatDataLength(size)
    }
        
    let shareButtonName: String = #localize("share")
    
    var isShareable: Bool {
        mdmManager.disableShareMedia() == false
    }
    
    private var shareableItem: UIActivityItemSource? {
        guard let data = BaseMessageEntityMessageShareContentMapper.mapToContent(
            from: fileMessageEntity,
            fileUtility: FileUtility.shared
        ) else {
            return nil
        }
        
        return UIActivityHelperFactory.makeItemSource(type: .messageActivity(data))
    }
    
    init(
        fileMessageEntity: FileMessageEntity,
        mdmManager: MDMSetup = MDMSetup()
    ) {
        self.fileMessageEntity = fileMessageEntity
        self.mdmManager = mdmManager
    }
    
    // A bit a hacky way to show share sheet in SwiftUI for types, that don't support `Transferable`
    // TODO: (IOS-5599) Adapt (file) messages to `Transferable` protocol
    func shareFile() {
        guard isShareable else {
            return
        }
        
        guard let shareableItem else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareableItem],
            applicationActivities: nil
        )
        if let currentWindow = AppDelegate.shared().currentTopViewController() {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = currentWindow.view
                activityViewController.popoverPresentationController?.sourceRect = CGRectMake(
                    currentWindow.view.bounds.maxX,
                    currentWindow.view.bounds.midY,
                    0,
                    0
                )
            }
            
            currentWindow.present(activityViewController, animated: true)
        }
    }
}
