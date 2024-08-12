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
    
    /// Optional if vote was updated or new
    var updatedVote: Bool?
}

// MARK: - SystemMessage

extension SystemMessage {
    
    // MARK: - SystemMessageType
    
    /// Type of the system message
    public enum SystemMessageType {
        case systemMessage(type: InfoType)
        case callMessage(type: CallType)
        case workConsumerInfo(type: WorkConsumerInfoType)
    }
    
    // MARK: - InfoType
    
    /// Types for messages not associated with calls
    public enum InfoType {
        case groupRenamed(newName: String)
        case groupMemberLeft(name: String)
        case groupMemberAdded(name: String)
        case groupMemberForcedLeave(name: String)
        case groupSelfAdded
        case groupSelfRemoved
        case groupSelfLeft
        case groupAvatarChanged
        case groupNoteGroupStarted
        case groupNoteGroupEnded
        case groupCreatorLeft
        case vote(info: VoteInfo?)
        case fsMessageWithoutForwardSecurity
        case fsSessionEstablished
        case fsSessionEstablishedRcvd
        case fsMessagesSkipped(numSkipped: Int)
        case fsSessionReset
        case fsMessageOutOfOrder
        case fsEnabledOutgoing
        case fsDisabledOutgoing
        case fsNotSupportedAnymore
        case systemMessageGroupCallStartedBy(name: String)
        case systemMessageGroupCallStarted
        case systemMessageGroupCallEnded
        case systemMessageUnsupportedType
        case fsDebugMessage(message: String)
        case fsIllegalSessionState
        
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
            
            case .groupAvatarChanged:
                return BundleUtil.localizedString(forKey: "system_message_group_avatar_changed")

            case .groupNoteGroupStarted:
                return BundleUtil.localizedString(forKey: "add_note_group_info")
                
            case .groupNoteGroupEnded:
                return BundleUtil.localizedString(forKey: "end_note_group_info")
                
            case .groupCreatorLeft:
                return BundleUtil.localizedString(forKey: "group_member_creator_left")
                
            case let .vote(info):
                guard let info else {
                    return BundleUtil.localizedString(forKey: "vote_system_message_default")
                }
                
                if info.showIntermediateResults {
                    if let voterName = info.voterName {
                        if let updatedVote = info.updatedVote,
                           updatedVote == true {
                            return String.localizedStringWithFormat(
                                BundleUtil.localizedString(forKey: "vote_system_message_update"),
                                voterName,
                                info.ballotTitle
                            )
                        }
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
                
            case .fsMessageWithoutForwardSecurity:
                return BundleUtil.localizedString(forKey: "forward_security_message_without")
                
            case .fsSessionEstablished:
                return BundleUtil.localizedString(forKey: "forward_security_session_established")
                
            case .fsSessionEstablishedRcvd:
                return BundleUtil.localizedString(forKey: "forward_security_session_established_rx")
                
            case let .fsMessagesSkipped(numSkipped):
                if numSkipped == 1 {
                    return BundleUtil.localizedString(forKey: "forward_security_messages_skipped_1")
                }
                else {
                    return String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "forward_security_messages_skipped_x"),
                        numSkipped
                    )
                }
                
            case .fsSessionReset:
                return BundleUtil.localizedString(forKey: "forward_security_session_reset")
            
            case .fsMessageOutOfOrder:
                return BundleUtil.localizedString(forKey: "forward_security_message_out_of_order")
                
            case .fsEnabledOutgoing:
                return BundleUtil.localizedString(forKey: "forward_security_status_enabled_outgoing")
                
            case .fsDisabledOutgoing:
                return BundleUtil.localizedString(forKey: "forward_security_status_disabled_outgoing")

            case .fsNotSupportedAnymore:
                return BundleUtil
                    .localizedString(forKey: "forward_security_contact_has_downgraded_to_an_incompatible_version")

            case let .systemMessageGroupCallStartedBy(name: name):
                if UserSettings.shared().enableThreemaGroupCalls {
                    return String.localizedStringWithFormat(
                        BundleUtil.localizedString(forKey: "group_call_started_by_contact_system_message"),
                        name
                    )
                }
                else {
                    return BundleUtil.localizedString(forKey: "group_call_started_disabled")
                }

            case .systemMessageGroupCallStarted:
                return BundleUtil.localizedString(forKey: "group_call_started_by_local_system_message")

            case .systemMessageGroupCallEnded:
                return BundleUtil.localizedString(forKey: "group_call_ended_system_message")

            case .systemMessageUnsupportedType:
                return BundleUtil.localizedString(forKey: "systemMessage_unsupported_type")

            case let .fsDebugMessage(message):
                return "kFsDebugMessage: \(message)"

            case .fsIllegalSessionState:
                return BundleUtil.localizedString(forKey: "forward_security_illegal_session_state")
            }
        }
    }
    
    // MARK: - CallType
    
    /// Types for messages associated with calls
    public enum CallType {
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
        public var localizedMessage: String {
            
            switch self {
            case .endedIncomingSuccessful:
                BundleUtil.localizedString(forKey: "call_incoming_ended")
                
            case .endedIncomingUnsuccessful:
                BundleUtil.localizedString(forKey: "call_missed")
                
            case .endedOutgoingSuccessful:
                BundleUtil.localizedString(forKey: "call_outgoing_ended")
                
            case .endedOutgoingUnsuccessful:
                BundleUtil.localizedString(forKey: "call_canceled")
                
            case .missedIncoming,
                 .missedOutgoing,
                 .rejectedTimeoutIncoming,
                 .rejectedUnknownIncoming,
                 .rejectedOffHoursIncoming:
                BundleUtil.localizedString(forKey: "call_missed")
                
            case .rejectedIncoming,
                 .rejectedOutgoing:
                BundleUtil.localizedString(forKey: "call_rejected")
                
            case .rejectedBusyIncoming,
                 .rejectedBusyOutgoing:
                BundleUtil.localizedString(forKey: "call_rejected_busy")
                
            case .rejectedTimeoutOutgoing:
                BundleUtil.localizedString(forKey: "call_rejected_timeout")
                
            case .rejectedDisabledIncoming,
                 .rejectedDisabledOutgoing:
                BundleUtil.localizedString(forKey: "call_rejected_disabled")
                
            case .rejectedUnknownOutgoing,
                 .rejectedOffHoursOutgoing:
                BundleUtil.localizedString(forKey: "call_rejected_unknown")
            }
        }
        
        /// Symbol for call type
        public var symbol: UIImage? {
            symbolImage?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
        
        /// Helper to resolve system and non-system symbols
        private var symbolImage: UIImage? {
            if let systemSymbol = UIImage(systemName: symbolName) {
                return systemSymbol
            }
            else if let customSymbol = UIImage(named: symbolName) {
                return customSymbol
            }
            
            return nil
        }
        
        /// Name of symbol for call type
        public var symbolName: String {
            switch self {
            // Incoming
            case .endedIncomingSuccessful:
                "phone.fill.arrow.down.left"
                
            case .rejectedIncoming,
                 .endedIncomingUnsuccessful,
                 .missedIncoming,
                 .rejectedBusyIncoming,
                 .rejectedTimeoutIncoming,
                 .rejectedDisabledIncoming,
                 .rejectedUnknownIncoming,
                 .rejectedOffHoursIncoming:
                "threema.phone.fill.arrow.bend.left"
                
            // Outgoing
            case .endedOutgoingSuccessful,
                 .endedOutgoingUnsuccessful:
                "phone.fill.arrow.up.right"

            case .missedOutgoing,
                 .rejectedOutgoing,
                 .rejectedBusyOutgoing,
                 .rejectedTimeoutOutgoing,
                 .rejectedDisabledOutgoing,
                 .rejectedUnknownOutgoing,
                 .rejectedOffHoursOutgoing:
                "threema.phone.fill.arrow.bend.right"
            }
        }
        
        /// Tint color for call type
        public var tintColor: UIColor {
            switch self {
            // Incoming
            case .endedIncomingSuccessful:
                Colors.green
                
            case .rejectedIncoming:
                Colors.orange
                
            case .endedIncomingUnsuccessful,
                 .missedIncoming,
                 .rejectedBusyIncoming,
                 .rejectedTimeoutIncoming,
                 .rejectedDisabledIncoming,
                 .rejectedUnknownIncoming,
                 .rejectedOffHoursIncoming:
                Colors.red
                
            // Outgoing
            case .endedOutgoingSuccessful:
                Colors.green
                
            case .endedOutgoingUnsuccessful:
                Colors.red
                
            case .missedOutgoing,
                 .rejectedOutgoing,
                 .rejectedBusyOutgoing,
                 .rejectedTimeoutOutgoing,
                 .rejectedDisabledOutgoing,
                 .rejectedUnknownOutgoing,
                 .rejectedOffHoursOutgoing:
                Colors.red
            }
        }
    }
    
    // MARK: - WorkConsumerInfoType
    
    /// Types for messages used to display consumer or private info
    public enum WorkConsumerInfoType {
        case work
        case consumer
        
        public var localizedMessage: String {
            switch self {
            case .work:
                BundleUtil.localizedString(forKey: "contact_threema_work_conversation_info")
            case .consumer:
                BundleUtil.localizedString(forKey: "contact_threema_conversation_info")
            }
        }
        
        public var symbol: UIImage? {
            switch self {
            case .work:
                StyleKit.workIcon
            case .consumer:
                StyleKit.houseIcon
            }
        }
        
        public var backgroundColor: UIColor {
            switch self {
            case .work:
                Colors.threemaWorkColor
            case .consumer:
                Colors.threemaConsumerColor
            }
        }
    }
    
    // MARK: - systemMessageType
    
    /// Type of system message
    public var systemMessageType: SystemMessageType {
        guard let typeValue = type?.intValue else {
            return .systemMessage(type: .systemMessageUnsupportedType)
        }
        
        // Since we use type to replace the direct use of itself, we can ignore the deprecate warning here
        switch typeValue {
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
            if ThreemaApp.current == .work || ThreemaApp.current == .blue {
                return .workConsumerInfo(type: .consumer)
            }
            else {
                return .workConsumerInfo(type: .work)
            }
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
        case 21:
            return .systemMessage(type: .fsMessageWithoutForwardSecurity)
        case 22:
            return .systemMessage(type: .fsSessionEstablished)
        case 23:
            return .systemMessage(type: .fsSessionEstablishedRcvd)
        case 24:
            return .systemMessage(type: .fsMessagesSkipped(numSkipped: Int(argAsUTF8String()) ?? 0))
        case 25:
            return .systemMessage(type: .fsSessionReset)
        case 26:
            return .systemMessage(type: .fsMessageOutOfOrder)
        case 27:
            return .systemMessage(type: .fsEnabledOutgoing)
        case 28:
            return .systemMessage(type: .fsDisabledOutgoing)
        case 29:
            return .systemMessage(type: .fsNotSupportedAnymore)
        case 30:
            let voteInfo = try? JSONDecoder().decode(VoteInfo.self, from: arg)
            return .systemMessage(type: .vote(info: voteInfo))
        case 32:
            return .systemMessage(type: .groupAvatarChanged)
        case 33:
            return .systemMessage(type: .systemMessageGroupCallStartedBy(name: argAsUTF8String()))
        case 34:
            return .systemMessage(type: .systemMessageGroupCallStarted)
        case 35:
            return .systemMessage(type: .systemMessageGroupCallEnded)
        case 36:
            return .systemMessage(type: .fsDebugMessage(message: argAsUTF8String()))
        case 37:
            return .systemMessage(type: .fsIllegalSessionState)
        default:
            DDLogError("Unsupported system message type with value")
            return .systemMessage(type: .systemMessageUnsupportedType)
        }
    }
}
