//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2023 Threema GmbH
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

#import "SystemMessage.h"
#import "LicenseStore.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation SystemMessage

@dynamic type;
@dynamic arg;

- (NSString*)format {
    NSDictionary *dict;
    switch (self.type.intValue) {
        case kSystemMessageContactOtherAppInfo:
            if ([LicenseStore requiresLicenseKey] == true) {
                return [BundleUtil localizedStringForKey:@"contact_threema_conversation_info"];
            } else {
                return [BundleUtil localizedStringForKey:@"contact_threema_work_conversation_info"];
            }
        case kSystemMessageRenameGroup:
            return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"group_renamed_to_x"], [self argAsUTF8String]];
        case kSystemMessageGroupMemberLeave:
            return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"group_member_x_left"], [self argAsUTF8String]];
        case kSystemMessageGroupMemberAdd:
            return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"group_member_x_added"], [self argAsUTF8String]];
        case kSystemMessageGroupMemberForcedLeave:
            return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"group_member_x_forced_leave"], [self argAsUTF8String]];
        case kSystemMessageGroupSelfAdded:
            return [BundleUtil localizedStringForKey:@"group_member_self_added"];
        case kSystemMessageGroupSelfRemoved:
            return [BundleUtil localizedStringForKey:@"group_member_self_removed"];
        case kSystemMessageGroupSelfLeft:
            return [BundleUtil localizedStringForKey:@"group_member_self_left"];
        case kSystemMessageGroupCreatorLeft:
            return [BundleUtil localizedStringForKey:@"group_member_creator_left"];
        case kSystemMessageStartNoteGroupInfo:
            return [BundleUtil localizedStringForKey:@"add_note_group_info"];
        case kSystemMessageEndNoteGroupInfo:
            return [BundleUtil localizedStringForKey:@"end_note_group_info"];
        case kSystemMessageCallMissed:
            return [BundleUtil localizedStringForKey:@"call_missed"];
        case kSystemMessageCallRejected:
            return [BundleUtil localizedStringForKey:@"call_rejected"];
        case kSystemMessageCallRejectedBusy:
            return [BundleUtil localizedStringForKey:@"call_rejected_busy"];
        case kSystemMessageCallRejectedTimeout:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return [BundleUtil localizedStringForKey:@"call_rejected_timeout"];
            } else {
                return [BundleUtil localizedStringForKey:@"call_missed"];
            }
        case kSystemMessageCallRejectedDisabled:
            return [BundleUtil localizedStringForKey:@"call_rejected_disabled"];
        case kSystemMessageVote:
            dict = [self argAsDictionary];
            
            // This depends on the codable keys defined in ´VoteInfo´
            if ([dict[@"showIntermediateResults"] boolValue]) {
                if (dict[@"voterID"]) {
                    return [NSString localizedStringWithFormat:[BundleUtil localizedStringForKey:@"vote_system_message"], dict[@"voterID"], dict[@"ballotTitle"]];
                } else {
                    return [BundleUtil localizedStringForKey:@"vote_system_message_default"];
                }
            } else {
                return [NSString localizedStringWithFormat: [BundleUtil localizedStringForKey:@"vote_system_message_hidden"], dict[@"ballotTitle"]] ;
            }
        case kSystemMessageVoteUpdated:
            dict = [self argAsDictionary];
            if (dict[@"voterID"]) {
                return [NSString localizedStringWithFormat:[BundleUtil localizedStringForKey:@"vote_system_message_update"], dict[@"voterID"], dict[@"ballotTitle"]];
            } else {
                return [BundleUtil localizedStringForKey:@"vote_system_message_default"];
            }
        case kSystemMessageCallRejectedOffHours:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return [BundleUtil localizedStringForKey:@"call_rejected_unknown"];
            } else {
                return [BundleUtil localizedStringForKey:@"call_missed"];
            }
        case kSystemMessageCallRejectedUnknown:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return [BundleUtil localizedStringForKey:@"call_rejected_unknown"];
            } else {
                return [BundleUtil localizedStringForKey:@"call_missed"];
            }
        case kSystemMessageCallEnded: {
            dict = [self argAsDictionary];
            NSString *callTime = dict[@"CallTime"];
            if (callTime && callTime.length > 0) {
                if ([dict[@"CallInitiator"] boolValue]) {
                    return [BundleUtil localizedStringForKey:@"call_outgoing_ended"];
                } else {
                    return [BundleUtil localizedStringForKey:@"call_incoming_ended"];
                }
            } else {
                if ([dict[@"CallInitiator"] boolValue]) {
                    return [BundleUtil localizedStringForKey:@"call_canceled"];
                } else {
                    return [BundleUtil localizedStringForKey:@"call_missed"];
                }
            }
        }
        case kSystemMessageFsMessageWithoutForwardSecurity:
            return [BundleUtil localizedStringForKey:@"forward_security_message_without"];
        case kSystemMessageFsSessionEstablished:
            return [BundleUtil localizedStringForKey:@"forward_security_session_established"];
        case kSystemMessageFsSessionEstablishedRcvd:
            return [BundleUtil localizedStringForKey:@"forward_security_session_established_rx"];
        case kSystemMessageFsMessagesSkipped: {
            NSInteger numSkipped = [[self argAsUTF8String] integerValue];
            if (numSkipped == 1) {
                return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"forward_security_messages_skipped_x"], numSkipped];
            } else {
                return [BundleUtil localizedStringForKey:@"forward_security_messages_skipped_1"];
            }
        }
        case kSystemMessageFsSessionReset:
            return [BundleUtil localizedStringForKey:@"forward_security_session_reset"];
        case kSystemMessageFsOutOfOrder:
            return [BundleUtil localizedStringForKey:@"forward_security_message_out_of_order"];
        case kSystemMessageFsEnabledOutgoing:
            return [BundleUtil localizedStringForKey:@"forward_security_status_enabled_outgoing"];
        case kSystemMessageFsDisabledOutgoing:
            return [BundleUtil localizedStringForKey:@"forward_security_status_disabled_outgoing"];
        case kSystemMessageFsNotSupportedAnymore:
            return [BundleUtil localizedStringForKey:@"forward_security_contact_has_downgraded_to_an_incompatible_version"];
        case kSystemMessageGroupCallStartedBy: {
            NSString *name = [self argAsUTF8String];
            return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"group_call_started_by_contact_system_message"], name];
        }
        case kSystemMessageGroupCallStarted:
          return [BundleUtil localizedStringForKey:@"group_call_started_by_local_system_message"];
        case kSystemMessageGroupCallEnded:
            return [BundleUtil localizedStringForKey:@"group_call_ended_system_message"];
        case kSystemMessageUnsupportedType:
            return [BundleUtil localizedStringForKey:@"systemMessage_unsupported_type"];
        case kSystemMessageGroupAvatarChanged:
            return [BundleUtil localizedStringForKey:@"system_message_group_avatar_changed"];
        case kFsDebugMessage:
            return [NSString stringWithFormat:@"FS Debug: %@", [self argAsUTF8String]];
        case kSystemMessageFsIllegalSessionState:
            return [BundleUtil localizedStringForKey:@"forward_security_illegal_session_state"];
    }
    
    return nil;
}

- (NSString *)callDetail {
    NSDictionary *dict;
    switch (self.type.intValue) {
        case kSystemMessageCallMissed:
        case kSystemMessageCallRejected:
        case kSystemMessageCallRejectedBusy:
        case kSystemMessageCallRejectedTimeout:
        case kSystemMessageCallRejectedDisabled:
        case kSystemMessageCallRejectedOffHours:
        case kSystemMessageCallRejectedUnknown:
        return nil;
        case kSystemMessageCallEnded:
            dict = [self argAsDictionary];
            NSString *callTime = dict[@"CallTime"];
            if (callTime && callTime.length > 0) {
                return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"call_duration"], dict[@"CallTime"]];
            }
            return nil;
    }
    
    return nil;
}

- (BOOL)isCallType {
    switch (self.type.integerValue) {
        case kSystemMessageCallMissed:
        case kSystemMessageCallRejected:
        case kSystemMessageCallRejectedBusy:
        case kSystemMessageCallRejectedTimeout:
        case kSystemMessageCallRejectedDisabled:
        case kSystemMessageCallRejectedOffHours:
        case kSystemMessageCallRejectedUnknown:
        case kSystemMessageCallEnded:
            return YES;
        default:
            return NO;
    }
}

- (BOOL)haveCallTime {
    NSDictionary *dict = [self argAsDictionary];
    NSString *callTime = dict[@"CallTime"];
    if (callTime && callTime.length > 0) {
        return YES;
    }
    return NO;
}

- (NSString *)callTime {
    NSDictionary *dict = [self argAsDictionary];
    NSString *callTime = dict[@"CallTime"];
    if (callTime && callTime.length > 0) {
        return callTime;
    }
    return nil;
}

- (NSString*)logText {
    return [self format];
}

- (NSString*)previewText {
    return [self format];
}

- (NSString *)argAsUTF8String {
    return [[NSString alloc] initWithData:self.arg encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)argAsDictionary {
    NSError *error;
    if (!self.arg || self.arg.length == 0) {
        return nil;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:self.arg options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        return nil;
    }
    return dict;
}

@end
