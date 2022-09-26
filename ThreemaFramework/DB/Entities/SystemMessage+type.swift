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

import CocoaLumberjackSwift
import Foundation

// MARK: - VoteInfo

/// Store infos about vote messages
public struct VoteInfo: Codable {
    /// Title of the ballot in which the vote was cast
    let ballotTitle: String
    /// ID of the voter
    let voterID: String
    /// Show intermediate results?
    let showIntermediateResults: Bool
    
    /// Optional string consisting of the display name of the voter
    var voterName: String? {
        let fetcher = EntityManager().entityFetcher
        let contact = fetcher.contact(for: voterID)
        return contact?.displayName
    }
}

// MARK: - SystemMessage

public extension SystemMessage {
    
    // MARK: - SystemMessageType
    
    /// Type of the system message
    enum SystemMessageType {
        case systemMessage(type: InfoType)
        case callMessage(type: CallType)
    }
    
    // MARK: - InfoType
    
    /// Types for messages not associated with calls
    enum InfoType {
        case groupRenamed(newName: String)
        case groupMemberLeft(name: String)
        case groupMemberAdded(name: String)
        case groupMemberForcedLeave(name: String)
        case groupSelfAdded
        case groupSelfRemoved
        case groupSelfLeft
        case groupNoteGroupStarted
        case groupNoteGroupEnded
        case contactUsesOtherApp
        case groupCreatorLeft
        case vote(info: VoteInfo?)
        
        /// Localized Message to display
        public var localizedMessage: String {
            switch self {
            case let .groupRenamed(name):
                return String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "group_renamed_to_x"), name)
                
            case let .groupMemberLeft(name):
                return String.localizedStringWithFormat(BundleUtil.localizedString(forKey: "group_member_x_left"), name)
                
            case let .groupMemberAdded(name):
                return String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "group_member_x_added"),
                    name
                )
                
            case let .groupMemberForcedLeave(name):
                return String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "group_member_x_forced_leave"),
                    name
                )
                
            case .groupSelfAdded:
                return BundleUtil.localizedString(forKey: "group_member_self_added")
                
            case .groupSelfRemoved:
                return BundleUtil.localizedString(forKey: "group_member_self_removed")
                
            case .groupSelfLeft:
                return BundleUtil.localizedString(forKey: "group_member_self_left")
                
            case .groupNoteGroupStarted:
                return BundleUtil.localizedString(forKey: "add_note_group_info")
                
            case .groupNoteGroupEnded:
                return BundleUtil.localizedString(forKey: "end_note_group_info")
                
            case .contactUsesOtherApp:
                if ThreemaApp.current == .work || ThreemaApp.current == .workRed {
                    return BundleUtil.localizedString(forKey: "contact_threema_conversation_info")
                }
                else {
                    return BundleUtil.localizedString(forKey: "contact_threema_work_conversation_info")
                }
                
            case .groupCreatorLeft:
                return BundleUtil.localizedString(forKey: "group_member_creator_left")
                
            case let .vote(info):
                guard let info = info else {
                    return BundleUtil.localizedString(forKey: "vote_system_message_default")
                }
                
                if info.showIntermediateResults {
                    if let voterName = info.voterName {
                        return String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "vote_system_message"),
                            voterName,
                            info.ballotTitle
                        )
                    }
                    else {
                        return BundleUtil.localizedString(forKey: "vote_system_message_default")
                    }
                }
                else {
                    return String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "vote_system_message_hidden"),
                        info.ballotTitle
                    )
                }
            }
        }
    }
    
    // MARK: - CallType
    
    /// Types for messages associated with calls
    enum CallType {
        // Ended with call time
        case endedIncomingSuccessful(duration: String)
        case endedOutgoingSuccessful(duration: String)
        
        // Ended but no call time
        case endedIncomingUnsuccessful
        case endedOutgoingUnsuccessful
        
        case missedIncoming
        case missedOutgoing
        
        case rejectedIncoming
        case rejectedOutgoing
        
        case rejectedBusyIncoming
        case rejectedBusyOutgoing
        
        case rejectedTimeoutIncoming
        case rejectedTimeoutOutgoing
        
        case rejectedDisabledIncoming
        case rejectedDisabledOutgoing
        
        case rejectedUnknownIncoming
        case rejectedUnknownOutgoing
        
        case rejectedOffHoursIncoming
        case rejectedOffHoursOutgoing
        
        /// Localized Message to display
        public var localizedMessage: String? {
            
            switch self {
            case .endedIncomingSuccessful:
                return BundleUtil.localizedString(forKey: "call_incoming_ended")
                
            case .endedIncomingUnsuccessful:
                return BundleUtil.localizedString(forKey: "call_missed")
                
            case .endedOutgoingSuccessful:
                return BundleUtil.localizedString(forKey: "call_outgoing_ended")
                
            case .endedOutgoingUnsuccessful:
                return BundleUtil.localizedString(forKey: "call_canceled")
                
            case .missedIncoming,
                 .missedOutgoing,
                 .rejectedTimeoutIncoming,
                 .rejectedUnknownIncoming,
                 .rejectedOffHoursIncoming:
                return BundleUtil.localizedString(forKey: "call_missed")
                
            case .rejectedIncoming,
                 .rejectedOutgoing:
                return BundleUtil.localizedString(forKey: "call_rejected")
                
            case .rejectedBusyIncoming,
                 .rejectedBusyOutgoing:
                return BundleUtil.localizedString(forKey: "call_rejected_busy")
                
            case .rejectedTimeoutOutgoing:
                return BundleUtil.localizedString(forKey: "call_rejected_timeout")
                
            case .rejectedDisabledIncoming,
                 .rejectedDisabledOutgoing:
                return BundleUtil.localizedString(forKey: "call_rejected_disabled")
                
            case .rejectedUnknownOutgoing,
                 .rejectedOffHoursOutgoing:
                return BundleUtil.localizedString(forKey: "call_rejected_unknown")
            }
        }
        
        /// Symbol for call type
        public var symbol: UIImage? {
            switch self {
            // Incoming
            case .endedIncomingSuccessful:
                return UIImage(
                    systemName: "phone.fill.arrow.down.left"
                )?
                    .withTintColor(Colors.green, renderingMode: .alwaysOriginal)
            case .rejectedIncoming:
                return UIImage(named: "threema.phone.fill.arrow.bend.left")?
                    .withTintColor(Colors.orange, renderingMode: .alwaysOriginal)
                
            case .endedIncomingUnsuccessful,
                 .missedIncoming,
                 .rejectedBusyIncoming,
                 .rejectedTimeoutIncoming,
                 .rejectedDisabledIncoming,
                 .rejectedUnknownIncoming,
                 .rejectedOffHoursIncoming:
                return UIImage(named: "threema.phone.fill.arrow.bend.left")?
                    .withTintColor(Colors.red, renderingMode: .alwaysOriginal)
                
            // Outgoing
            case .endedOutgoingSuccessful:
                return UIImage(
                    systemName: "phone.fill.arrow.up.right"
                )?
                    .withTintColor(Colors.green, renderingMode: .alwaysOriginal)
                
            case .endedOutgoingUnsuccessful:
                return UIImage(
                    systemName: "phone.fill.arrow.up.right"
                )?
                    .withTintColor(Colors.red, renderingMode: .alwaysOriginal)
                
            case .missedOutgoing,
                 .rejectedOutgoing,
                 .rejectedBusyOutgoing,
                 .rejectedTimeoutOutgoing,
                 .rejectedDisabledOutgoing,
                 .rejectedUnknownOutgoing,
                 .rejectedOffHoursOutgoing:
                return UIImage(named: "threema.phone.fill.arrow.bend.right")?
                    .withTintColor(Colors.red, renderingMode: .alwaysOriginal)
            }
        }
    }
    
    // MARK: - systemMessageType
    
    /// Type of system message
    var systemMessageType: SystemMessageType {
        // Since we use type to replace the direct use of itself, we can ignore the deprecate warning here
        switch type.intValue {
        case 1:
            return .systemMessage(type: .groupRenamed(newName: argAsUTF8String()))
        case 2:
            return .systemMessage(type: .groupMemberLeft(name: argAsUTF8String()))
        case 3:
            return .systemMessage(type: .groupMemberAdded(name: argAsUTF8String()))
        case 4:
            return .systemMessage(type: .groupMemberForcedLeave(name: argAsUTF8String()))
        case 5:
            return .systemMessage(type: .groupSelfAdded)
        case 6:
            return .systemMessage(type: .groupSelfRemoved)
        case 7:
            if isOwnMessage {
                return .callMessage(type: .missedOutgoing)
            }
            return .callMessage(type: .missedIncoming)
        case 8:
            if isOwnMessage {
                return .callMessage(type: .rejectedOutgoing)
            }
            return .callMessage(type: .rejectedIncoming)
        case 9:
            if isOwnMessage {
                return .callMessage(type: .rejectedBusyOutgoing)
            }
            return .callMessage(type: .rejectedBusyIncoming)
        case 10:
            if isOwnMessage {
                return .callMessage(type: .rejectedTimeoutOutgoing)
            }
            return .callMessage(type: .rejectedTimeoutIncoming)
        case 11:
            if isOwnMessage {
                if let duration = callTime() {
                    return .callMessage(type: .endedOutgoingSuccessful(duration: duration))
                }
                return .callMessage(type: .endedOutgoingUnsuccessful)
            }
            else {
                if let duration = callTime() {
                    return .callMessage(type: .endedIncomingSuccessful(duration: duration))
                }
                return .callMessage(type: .endedIncomingUnsuccessful)
            }
        case 12:
            if isOwnMessage {
                return .callMessage(type: .rejectedDisabledOutgoing)
            }
            return .callMessage(type: .rejectedDisabledIncoming)
        case 13:
            if isOwnMessage {
                return .callMessage(type: .rejectedUnknownOutgoing)
            }
            return .callMessage(type: .rejectedUnknownIncoming)
        case 14:
            
            return .systemMessage(type: .contactUsesOtherApp)
        case 15:
            if isOwnMessage {
                return .callMessage(type: .rejectedOffHoursOutgoing)
            }
            return .callMessage(type: .rejectedOffHoursIncoming)
        case 16:
            return .systemMessage(type: .groupSelfLeft)
        case 17:
            return .systemMessage(type: .groupNoteGroupStarted)
        case 18:
            return .systemMessage(type: .groupNoteGroupEnded)
        case 19:
            return .systemMessage(type: .groupCreatorLeft)
        case 20:
            let voteInfo = try? JSONDecoder().decode(VoteInfo.self, from: arg)
            return .systemMessage(type: .vote(info: voteInfo))
        default:
            DDLogError("Unsupported system message type with value")
            fatalError("Unsupported system message type with value")
        }
    }
}
