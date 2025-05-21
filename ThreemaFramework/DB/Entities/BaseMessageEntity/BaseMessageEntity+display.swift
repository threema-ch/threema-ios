//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import Foundation
import ThreemaMacros

extension BaseMessageEntity {
    
    /// State to display in UI for this message
    public enum DisplayState {
        case none
        
        // Outgoing (own) messages
        case sending
        case sent
        case delivered
        case read
        case failed
        
        /// Symbol variants
        public enum SymbolVariant {
            // Default without circle or filled
            case `default`
            // Filled symbol
            case fill
        }
        
        /// Get symbol for current state if appropriate
        /// - Parameter defaultColor: Default color to use for symbol if it does not have a specific color
        /// - Parameter variant: Optional variant configuration
        /// - Returns: Symbol image if appropriate for this state, otherwise `nil`
        public func symbol(with defaultColor: UIColor, variant: SymbolVariant = .fill) -> UIImage? {
            switch self {
            case .none:
                return nil
                                
            case .sending:
                // We don't want a filled version here
                return UIImage(systemName: "arrow.up.circle")?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
                
            case .sent:
                let symbolName = resolvedSymbolName(for: "envelope", variant: variant)
                return UIImage(systemName: symbolName)?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
                
            case .delivered:
                let symbolName = resolvedSymbolName(for: "tray.and.arrow.down", variant: variant)
                return UIImage(systemName: symbolName)?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
                
            case .read:
                let symbolName = resolvedSymbolName(for: "eye", variant: variant)
                return UIImage(systemName: symbolName)?
                    .withTintColor(defaultColor, renderingMode: .alwaysOriginal)
                
            case .failed:
                let symbolName = resolvedSymbolName(for: "exclamationmark.triangle", variant: variant)
                return UIImage(systemName: symbolName)?
                    .withTintColor(Colors.messageFailed, renderingMode: .alwaysOriginal)
            }
        }
        
        private func resolvedSymbolName(for symbolName: String, variant: SymbolVariant) -> String {
            switch variant {
            case .default:
                symbolName
            case .fill:
                symbolName.appending(".fill")
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
        
        public func localizedLabel(for message: BaseMessageEntity) -> String {
            switch self {
            case .none:
                #localize("message_display_status_none")
            case .sending:
                #localize("message_display_status_sending")
            case .sent:
                #localize("message_display_status_sent")
            case .delivered:
                if message.isOwnMessage {
                    #localize("message_display_status_delivered")
                }
                else {
                    #localize("message_display_status_delivered_incoming")
                }
            case .read:
                #localize("message_display_status_read")
            case .failed:
                #localize("message_display_status_failed")
            }
        }
        
        /// Accessibility label for current state
        public var accessibilityLabel: String {
            switch self {
            case .none:
                ""
            case .sending:
                #localize("accessibility_status_sending_plus_time")
            case .sent:
                #localize("accessibility_status_sent_plus_time")
            case .delivered:
                #localize("accessibility_status_delivered_plus_time")
            case .read:
                #localize("accessibility_status_read_plus_time")
            case .failed:
                #localize("accessibility_status_failed_plus_time")
            }
        }
    }
    
    // MARK: - Message action images
    
    public var messageMarkerStarImage: UIImage? {
        var imageName = "star"
        if messageMarkers?.star.boolValue ?? false {
            imageName = "star.slash"
        }
        return UIImage(systemName: imageName)
    }
    
    // MARK: - messageDisplayState
    
    /// Display state for this message. Use this to show symbols in UI.
    public var messageDisplayState: DisplayState {
        
        // We don't show state in system messages
        if self is SystemMessageEntity {
            return .none
        }
        
        if isGroupMessage ||
            conversation.contact?.isGatewayID ?? false {
            return displayStateForGatewayOrGroupMessage
        }
        else {
            return displayStateForSingleMessage
        }
    }
    
    private var displayStateForSingleMessage: DisplayState {
        switch messageState {
        case .sending:
            .sending
            
        case .sent:
            .sent
            
        case .delivered:
            .delivered
            
        case .failed:
            .failed
            
        case .received:
            .none
            
        case .read:
            if isOwnMessage {
                .read
            }
            else {
                .none
            }
        }
    }
    
    private var displayStateForGatewayOrGroupMessage: DisplayState {
        switch messageState {
        case .sending:
            .sending
        case .sent, .delivered, .received, .read:
            .none
        case .failed:
            .failed
        }
    }
    
    // MARK: - displayDate
    
    /// Display date of this message
    ///
    /// Use this to show a formatted date (maybe just time) in the UI.
    @objc public var displayDate: Date {
        // If user delete a message, the conversation property in the message is nil
        // We have to use the date if it's on state willBeDeleted
        if willBeDeleted {
            return date
        }
            
        if isGroupMessage {
            if isOwnMessage {
                return date
            }
            else {
                return remoteSentDate ?? .now
            }
        }
        else {
            return displayDateForSingleMessage
        }
    }
    
    private var displayDateForSingleMessage: Date {
        // Date is independent of fail state!
        if isOwnMessage {
            if read.boolValue, let readDate {
                return readDate
            }
            else if delivered.boolValue, let deliveryDate {
                return deliveryDate
            }
            // Sent and everything else
            return date
        }
        return remoteSentDate ?? .now
    }
    
    // MARK: - Date for state
    
    /// Date associated with a certain state
    ///
    /// This is "independent" of the current message state. I.e. if the message is not actually delivered, but a
    /// `deliveryDate` is set this will be returned.
    ///
    /// - Parameter state: State go get date for
    /// - Returns: Date if there is any for this state
    public func date(for state: DisplayState) -> Date? {
        switch state {
        case .none:
            return nil
            
        case .sending:
            return nil
            
        case .sent:
            // `remoteSendDate` returns `date` if it is `nil`. To not just return `date` in general we only return
            // `remoteSentDate` when an outgoing message is actually sent out
            if isOwnMessage,
               !sent.boolValue {
                return nil
            }
            
            return remoteSentDate
            
        case .delivered:
            return deliveryDate
            
        case .read:
            return readDate
            
        case .failed:
            return nil
        }
    }
}
