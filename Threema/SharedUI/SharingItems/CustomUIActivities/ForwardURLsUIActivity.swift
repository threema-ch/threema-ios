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

import Foundation
import ThreemaFramework
import ThreemaMacros
import UIKit

final class ForwardURLsUIActivity: UIActivity {
    private static let urlKey = "url"
    private static let renderTypeKey = "renderType"
    private static let maxForwardItemsCount = 20

    private let bundleService: BundleServiceProtocol
    private var objects: [[String: Any]] = []

    init(bundleService: BundleServiceProtocol) {
        self.bundleService = bundleService
    }

    override class var activityCategory: UIActivity.Category {
        .action
    }

    override var activityType: UIActivity.ActivityType? {
        ActivityType("\(bundleService.mainBundleIdentifier ?? "").forwardMsg")
    }

    override var activityTitle: String? {
        #localize("forward")
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "arrowshape.turn.up.right.fill")
    }

    override var activityViewController: UIViewController? {
        guard
            let navController = ContactGroupPickerViewController.pickerFromStoryboard(withDelegate: self),
            let pickerController = navController.topViewController as? ContactGroupPickerViewController
        else {
            return nil
        }

        pickerController.enableMultiSelection = true
        pickerController.enableTextInput = true
        pickerController.submitOnSelect = false

        // In case of multiple items, we use the renderType value of the first item forwarded
        pickerController.renderType = objects.first?[Self.renderTypeKey] as? NSNumber ?? NSNumber(value: 0)

        return navController
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard activityItems.count <= Self.maxForwardItemsCount else {
            return false
        }

        let allItemsSatisfy = activityItems.allSatisfy { item in
            if item is URL {
                true
            }
            else if let itemDict = item as? [String: Any], itemDict[Self.urlKey] is URL {
                true
            }
            else {
                false
            }
        }

        return allItemsSatisfy
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        objects.removeAll()
        for item in activityItems {
            if let itemDict = item as? [String: Any], let url = itemDict[Self.urlKey] as? URL {
                var object: [String: Any] = [:]
                object[Self.urlKey] = url
                object[Self.renderTypeKey] = itemDict[Self.renderTypeKey] ?? NSNumber(value: 0)
                objects.append(object)
            }
            if item is URL {
                let object: [String: Any] = [
                    Self.urlKey: item,
                    Self.renderTypeKey: NSNumber(value: 0),
                ]
                objects.append(object)
            }
        }
    }
}

// MARK: - ContactGroupPickerDelegate

extension ForwardURLsUIActivity: ContactGroupPickerDelegate {
    func contactPicker(
        _ contactPicker: ContactGroupPickerViewController,
        didPickConversations conversations: Set<AnyHashable>,
        renderType: NSNumber,
        sendAsFile: Bool
    ) {
        let urls = objects.compactMap { $0[Self.urlKey] as? URL }
        let conversations = conversations as? Set<ConversationEntity> ?? []
        for url in urls {
            for conversation in conversations {
                URLSender.sendURL(
                    url,
                    asFile: sendAsFile,
                    caption: contactPicker.additionalTextToSend,
                    conversation: conversation
                )
            }
        }
        contactPicker.dismiss(animated: true) { [weak self] in
            self?.activityDidFinish(true)
        }
    }

    func contactPickerDidCancel(_ contactPicker: ContactGroupPickerViewController) {
        contactPicker.dismiss(animated: true) { [weak self] in
            self?.activityDidFinish(false)
        }
    }
}

// MARK: - ModalNavigationControllerDelegate

extension ForwardURLsUIActivity: ModalNavigationControllerDelegate {
    func didDismissModalNavigationController() {
        activityDidFinish(true)
    }
}
