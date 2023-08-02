//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import GroupCalls
import JDStatusBarNotification
import SwiftUI

/// Show unobtrusive notifications in pill-shape
///
/// Use `shared` to do so.
@objc public class NotificationPresenterWrapper: NSObject {
    
    /// Shared wrapper to be used
    @objc public static var shared = NotificationPresenterWrapper()
    
    private static let presenter = NotificationPresenter.shared()
    private static let hapticGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Enums
    
    /// Contains values to use in notification parameter configuration
    private enum Configuration {
        /// Default delay until notification  hides itself
        static let defaultDelay = TimeInterval(3.5)
        /// Default shadowRadius of notification pill
        static let defaultShadowRadius = 3.0
        /// Default font of the main text label of the notification
        static let defaultFont = UIFont.preferredFont(forTextStyle: .footnote)
    }
    
    // MARK: - Lifecycle
    
    override public init() {
        super.init()
        
        initializeStyles()
    }
    
    // MARK: - Public Functions
    
    /// Presents an unobtrusive notification in pill-shape
    /// - Parameters:
    ///   - type:  Type to use for notification
    ///   - subtitle: Optional subtitle
    ///   - completion: Called after notification is displayed.
    public func present(
        type: NotificationPresenterType,
        subtitle: String? = nil,
        completion: NotificationPresenterCompletion? = nil
    ) {
        
        Task { @MainActor in
            NotificationPresenterWrapper.presenter
                .present(text: type.notificationText, customStyle: type.notificationStyle.id) { presenter in
                    
                    presenter.dismiss(afterDelay: Configuration.defaultDelay)
                    
                    completion?(presenter)
                }
            
            NotificationPresenterWrapper.presenter.updateSubtitle(subtitle)
            
            if let imageView = type.notificationStyle.notificationImageView {
                NotificationPresenterWrapper.presenter.displayLeftView(imageView)
            }
            
            if let hapticType = type.notificationStyle.hapticType {
                NotificationPresenterWrapper.hapticGenerator.prepare()
                NotificationPresenterWrapper.hapticGenerator.notificationOccurred(hapticType)
            }
        }
    }
    
    /// Presents an unobtrusive notification in pill-shape indefinitely
    /// - Parameters:
    ///   - text: Text to be displayed in notification, If nil, a default value is used.
    ///   - style: Style to use in notification.
    ///   - completion: Called after notification is displayed.
    public func presentIndefinitely(
        text: String? = nil,
        type: NotificationPresenterType,
        completion: NotificationPresenterCompletion? = nil
    ) {
        
        Task { @MainActor in
            NotificationPresenterWrapper.presenter
                .present(text: type.notificationText, customStyle: type.notificationStyle.id) { presenter in
                    
                    completion?(presenter)
                }
            if let imageView = type.notificationStyle.notificationImageView {
                NotificationPresenterWrapper.presenter.displayLeftView(imageView)
            }
            if let hapticType = type.notificationStyle.hapticType {
                NotificationPresenterWrapper.hapticGenerator.prepare()
                NotificationPresenterWrapper.hapticGenerator.notificationOccurred(hapticType)
            }
        }
    }

    @objc public func dismissAllPresentedNotifications() {
        NotificationPresenterWrapper.presenter.dismiss()
    }
    
    @available(*, deprecated, message: "Do not use from Obj-C anymore")
    @objc public func presentIDVerified() {
        let type = NotificationPresenterType(
            notificationText: BundleUtil.localizedString(forKey: "id_verified_title"),
            notificationStyle: .success
        )
        present(type: type)
    }
    
    @available(*, deprecated, message: "Do not use from Obj-C anymore")
    @objc public func presentUpdateWorkDataError() {
        present(type: .updateWorkDataFailed)
    }
    
    // MARK: - Styles
    
    private func initializeStyles() {
        // General
        NotificationPresenter.shared()
            .addStyle(styleName: NotificationPresenterStyle.none.id) { style in
                applyDefaultBackgroundParameters(to: &style.backgroundStyle)
                applyDefaultTextParameters(to: &style.textStyle)
                applyDefaultImageParameters(to: &style.leftViewStyle)

                return style
            }
        
        // Success
        NotificationPresenter.shared()
            .addStyle(styleName: NotificationPresenterStyle.success.id) { style in
                applyDefaultBackgroundParameters(to: &style.backgroundStyle)
                applyDefaultTextParameters(to: &style.textStyle)
                applyDefaultImageParameters(to: &style.leftViewStyle)

                return style
            }
        
        // Error
        NotificationPresenter.shared()
            .addStyle(styleName: NotificationPresenterStyle.error.id) { style in
                applyDefaultBackgroundParameters(to: &style.backgroundStyle)
                applyDefaultTextParameters(to: &style.textStyle)
                applyDefaultImageParameters(to: &style.leftViewStyle)

                return style
            }
    }
    
    @objc public func colorChanged() {
        NotificationPresenterWrapper.shared = NotificationPresenterWrapper()
    }
    
    // MARK: - Default parameter functions
    
    private func applyDefaultBackgroundParameters(to style: inout StatusBarNotificationBackgroundStyle) {
        style.pillStyle.shadowColor = Colors.pillShadow
        style.backgroundColor = Colors.pillBackground
        style.pillStyle.shadowRadius = Configuration.defaultShadowRadius
    }
    
    private func applyDefaultTextParameters(to style: inout StatusBarNotificationTextStyle) {
        style.textColor = Colors.textLight
        style.font = Configuration.defaultFont
    }
    
    private func applyDefaultImageParameters(to style: inout StatusBarNotificationLeftViewStyle) {
        style.alignment = .left
    }
}

// MARK: - NotificationPresenterWrapperProtocol

extension NotificationPresenterWrapper: NotificationPresenterWrapperProtocol {
    public func presentGroupCallNotification(type: GroupCalls.GroupCallNotificationType) {
        switch type {
        case .audioMuted:
            present(type: NotificationPresenterType.audioMuted)
        case .audioUnmuted:
            present(type: NotificationPresenterType.audioUnmuted)
        case .videoMuted:
            present(type: NotificationPresenterType.videoMuted)
        case .videoUnmuted:
            present(type: NotificationPresenterType.videoUnmuted)
        }
    }
}
