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

import CocoaLumberjackSwift
import FileUtility
import Foundation
import UIKit

final class MessageUIActivityItemSource: NSObject {
    struct MessageShareContent {
        let type: ContentType
        let dataTypeIdentifier: String
        let exportURL: URL

        enum ContentType {
            case text(String)
            case audio(Data)
            case image(Data)
            case video(Data)
            case file(Data, renderType: Int)
        }
    }

    private static let urlKey = "url"
    private static let renderTypeKey = "renderType"

    let content: MessageShareContent
    private let fileUtility: FileUtilityProtocol
    private var didExportData = false
    private let forwardMessageActivityType = "ch.threema.iapp.forwardMsg"

    init(
        content: MessageShareContent,
        fileUtility: FileUtilityProtocol
    ) {
        self.content = content
        self.fileUtility = fileUtility
        super.init()
    }

    // MARK: - Helpers

    private func exportData() {
        if didExportData {
            return
        }
        didExportData = true
        
        switch content.type {
        case .text:
            break
            
        case let .audio(data):
            fileUtility.write(contents: data, to: content.exportURL)
            
        case let .image(data):
            fileUtility.write(contents: data, to: content.exportURL)
            
        case let .video(data):
            fileUtility.write(contents: data, to: content.exportURL)
            
        case let .file(data, _):
            fileUtility.write(contents: data, to: content.exportURL)
        }
    }
}

// MARK: - UIActivityItemSource

extension MessageUIActivityItemSource: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        if case let .text(message) = content.type {
            return message
        }
        else {
            // Note: Thumbnail images cannot be returned here - the API doesn't support it.
            // Some share activities require the file to be exported to a temporary location
            // before they appear in the share menu. These temporary files will be automatically
            // cleaned up by ActivityUtil after the share activity completes.
            exportData()
            return content.exportURL
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        switch content.type {
        case let .text(message):
            message

        case let .file(_, renderType):
            if activityType?.rawValue == forwardMessageActivityType {
                [
                    Self.urlKey: content.exportURL as Any,
                    Self.renderTypeKey: renderType as Any,
                ]
            }
            else {
                content.exportURL
            }

        default:
            content.exportURL
        }
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        content.dataTypeIdentifier
    }
}
