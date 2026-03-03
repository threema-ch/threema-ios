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
import UIKit

final class UIActivityHelperFactory: NSObject, Sendable {
    enum ItemSourceType {
        case zipFile(url: URL, subject: String)
        case messageActivity(MessageUIActivityItemSource.MessageShareContent)
    }

    enum ActivityType {
        case forwardURLs
    }

    static func makeItemSource(type: ItemSourceType) -> UIActivityItemSource {
        switch type {
        case let .zipFile(url: url, subject: subject):
            ZipFileUIActivityItemProvider(url: url, subject: subject)

        case let .messageActivity(content):
            MessageUIActivityItemSource(
                content: content,
                fileUtility: FileUtility.shared
            )
        }
    }

    static func makeActivity(type: ActivityType) -> UIActivity {
        switch type {
        case .forwardURLs:
            ForwardURLsUIActivity(bundleService: .live)
        }
    }
}

@available(swift, deprecated: 1.0, message: "Use makeActivity(type:) instead")
extension UIActivityHelperFactory {
    @objc static func makeForwardURLsUIActivity() -> ForwardURLsUIActivity {
        ForwardURLsUIActivity(bundleService: .live)
    }
}
