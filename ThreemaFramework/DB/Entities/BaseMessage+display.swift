//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

public extension BaseMessage {
    
    /// State to display in UI for this message
    enum DisplayState {
        case none
        
        // Common states
        case userAcknowledged
        case userDeclined
        
        // Outgoing (own) messages
        case sending
        case sent
        case delivered
        case read
        case failed
        
        /// Get symbol for current state if appropriate
        /// - Parameter defaultColor: Default color to use for symbol if it does not have a specific color
        /// - Returns: Symbol image if appropriate for this state, otherwise `nil`
        public func symbol(with defaultColor: UIColor) -> UIImage? {
            switch self {
            case .none:
                return nil
            case .userAcknowledged:
                return UIImage(systemName: "hand.thumbsup.fill")?
                    .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
            case .userDeclined:
                return UIImage(systemName: "hand.thumbsdown.fill")?
                    .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
            case .sending:
                return UIImage(systemName: "arrow.up.circle")?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .sent:
                return UIImage(systemName: "envelope.fill")?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .delivered:
                return UIImage(systemName: "tray.and.arrow.down.fill")?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .read:
                return UIImage(systemName: "eye.fill")?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .failed:
                return UIImage(systemName: "exclamationmark.triangle.fill")?
                    .withTintColor(Colors.messageFailed, renderingMode: .alwaysOriginal)
            }
        }
        
        /// Get overview symbol for current state if appropriate
        /// - Parameter defaultColor: Default color to use for symbol if it does not have a specific color
        /// - Returns: Symbol image if appropriate for this state, otherwise `nil`
        public func overviewSymbol(
            with defaultColor: UIColor,
            ownMessage: Bool,
            configuration: UIImage.SymbolConfiguration
        ) -> UIImage? {
            switch self {
            case .none:
                if !ownMessage {
                    return UIImage(
                        systemName: "arrowshape.turn.up.left",
                        withConfiguration: configuration
                    )?
                        .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
                }
                return nil
            case .userAcknowledged:
                if !ownMessage {
                    return UIImage(
                        systemName: "arrowshape.turn.up.left",
                        withConfiguration: configuration
                    )?
                        .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
                }
                return UIImage(
                    systemName: "hand.thumbsup.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
            case .userDeclined:
                if !ownMessage {
                    return UIImage(
                        systemName: "arrowshape.turn.up.left",
                        withConfiguration: configuration
                    )?
                        .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
                }
                return UIImage(
                    systemName: "hand.thumbsdown.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
            case .sending:
                return UIImage(
                    systemName: "arrow.up.circle",
                    withConfiguration: configuration
                )?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .sent:
                return UIImage(
                    systemName: "envelope.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .delivered:
                return UIImage(
                    systemName: "tray.and.arrow.down.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .read:
                return UIImage(
                    systemName: "eye.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
            case .failed:
                return UIImage(
                    systemName: "exclamationmark.triangle.fill",
                    withConfiguration: configuration
                )?
                    .withTintColor(Colors.messageFailed, renderingMode: .alwaysOriginal)
            }
        }
        
        /// Accessibility label for current state
        public func accessibilityLabel() -> String {
            switch self {
            case .none:
                return ""
            case .userAcknowledged:
                return BundleUtil.localizedString(forKey: "accessibility_status_acknowledged_plus_time")
            case .userDeclined:
                return BundleUtil.localizedString(forKey: "accessibility_status_declined_plus_time")
            case .sending:
                return BundleUtil.localizedString(forKey: "accessibility_status_sending_plus_time")
            case .sent:
                return BundleUtil.localizedString(forKey: "accessibility_status_sent_plus_time")
            case .delivered:
                return BundleUtil.localizedString(forKey: "accessibility_status_delivered_plus_time")
            case .read:
                return BundleUtil.localizedString(forKey: "accessibility_status_read_plus_time")
            case .failed:
                return BundleUtil.localizedString(forKey: "accessibility_status_failed_plus_time")
            }
        }
    }
    
    // MARK: - ack images
    
    var userThumbsUpImage: UIImage? {
        var imageName = "hand.thumbsup"
        if userackDate != nil, userack.boolValue {
            imageName = "hand.thumbsup.fill"
        }
        return UIImage(systemName: imageName)?
            .withTintColor(Colors.thumbUp, renderingMode: .alwaysOriginal)
    }
    
    var userThumbsDownImage: UIImage? {
        var imageName = "hand.thumbsdown"
        if userackDate != nil, !userack.boolValue {
            imageName = "hand.thumbsdown.fill"
        }
        return UIImage(systemName: imageName)?
            .withTintColor(Colors.thumbDown, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - messageDisplayState
    
    /// Display state for this message. Use this to show symbols in UI.
    var messageDisplayState: DisplayState {
        
        // We don't show state in system messages
        if self is SystemMessage {
            return .none
        }
        
        if conversation.isGroup() ||
            conversation.contact?.isGatewayID() ?? false {
            return displayStateForGatewayOrGroupMessage
        }
        else {
            return displayStateForSingleMessage
        }
    }
    
    private var displayStateForSingleMessage: DisplayState {
        switch messageState {
        case .sending:
            return .sending
        case .sent:
            return .sent
        case .delivered:
            return .delivered
        case .failed:
            return .failed
            
        case .received:
            return .none
            
        case .read:
            if isOwnMessage {
                return .read
            }
            else {
                return .none
            }

        case .userAcknowledged:
            return .userAcknowledged
        case .userDeclined:
            return .userDeclined
        }
    }
    
    private var displayStateForGatewayOrGroupMessage: DisplayState {
        switch messageState {
        case .sending:
            return .sending
        case .sent, .delivered, .received, .read:
            return .none
        case .failed:
            return .failed
        case .userAcknowledged:
            return .userAcknowledged
        case .userDeclined:
            return .userDeclined
        }
    }
    
    // MARK: - displayDate
    
    /// Display date of this message
    ///
    /// Use this to show a formatted date (maybe just time) in the UI.
    @objc var displayDate: Date {
        // If user delete a message, the conversation property in the message is nil
        // We have to use the date if it's on state willBeDeleted
        if willBeDeleted {
            return date
        }

        if let userackDate = userackDate {
            return userackDate
        }
            
        if conversation.isGroup() {
            if isOwnMessage {
                return date
            }
            else {
                return remoteSentDate
            }
        }
        else {
            return displayDateForSingleMessage
        }
    }
    
    private var displayDateForSingleMessage: Date {
        // Date is independent of fail state!
        if isOwnMessage {
            if read.boolValue, let readDate = readDate {
                return readDate
            }
            else if delivered.boolValue, let deliveryDate = deliveryDate {
                return deliveryDate
            }
            // Sent and everything else
            else {
                return date
            }
        }
        else {
            return remoteSentDate
        }
    }
}
