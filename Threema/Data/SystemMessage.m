//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2021 Threema GmbH
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
#import "Contact.h"
#import "LicenseStore.h"

@implementation SystemMessage

@dynamic type;
@dynamic arg;

- (NSString*)format {
    NSDictionary *dict;
    switch (self.type.intValue) {
        case kSystemMessageContactOtherAppInfo:
            if ([LicenseStore requiresLicenseKey] == true) {
                return NSLocalizedString(@"contact_threema_conversation_info", nil);
            } else {
                return NSLocalizedString(@"contact_threema_work_conversation_info", nil);
            }
        case kSystemMessageRenameGroup:
            return [NSString stringWithFormat:NSLocalizedString(@"group_renamed_to_x", nil), [self argAsUTF8String]];
        case kSystemMessageGroupMemberLeave:
            return [NSString stringWithFormat:NSLocalizedString(@"group_member_x_left", nil), [self argAsUTF8String]];
        case kSystemMessageGroupMemberAdd:
            return [NSString stringWithFormat:NSLocalizedString(@"group_member_x_added", nil), [self argAsUTF8String]];
        case kSystemMessageGroupMemberForcedLeave:
            return [NSString stringWithFormat:NSLocalizedString(@"group_member_x_forced_leave", nil), [self argAsUTF8String]];
        case kSystemMessageGroupSelfAdded:
            return NSLocalizedString(@"group_member_self_added", nil);
        case kSystemMessageGroupSelfRemoved:
            return NSLocalizedString(@"group_member_self_removed", nil);
        case kSystemMessageGroupSelfLeft:
            return NSLocalizedString(@"group_member_self_left", nil);
        case kSystemMessageCallMissed:
            return NSLocalizedString(@"call_missed", nil);
        case kSystemMessageCallRejected:
            return NSLocalizedString(@"call_rejected", nil);
        case kSystemMessageCallRejectedBusy:
            return NSLocalizedString(@"call_rejected_busy", nil);
        case kSystemMessageCallRejectedTimeout:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return NSLocalizedString(@"call_rejected_timeout", nil);
            } else {
                return NSLocalizedString(@"call_missed", nil);
            }
        case kSystemMessageCallRejectedDisabled:
            return NSLocalizedString(@"call_rejected_disabled", nil);
        case kSystemMessageCallRejectedOffHours:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return NSLocalizedString(@"call_rejected_unknown", nil);
            } else {
                return NSLocalizedString(@"call_missed", nil);
            }
        case kSystemMessageCallRejectedUnknown:
            dict = [self argAsDictionary];
            if ([dict[@"CallInitiator"] boolValue]) {
                return NSLocalizedString(@"call_rejected_unknown", nil);
            } else {
                return NSLocalizedString(@"call_missed", nil);
            }
        case kSystemMessageCallEnded:
            dict = [self argAsDictionary];
            NSString *callTime = dict[@"CallTime"];
            if (callTime && callTime.length > 0) {
                if ([dict[@"CallInitiator"] boolValue]) {
                    return NSLocalizedString(@"call_outgoing_ended", nil);
                } else {
                    return NSLocalizedString(@"call_incoming_ended", nil);
                }
            } else {
                if ([dict[@"CallInitiator"] boolValue]) {
                    return NSLocalizedString(@"call_canceled", nil);
                } else {
                    return NSLocalizedString(@"call_missed", nil);
                }
            }
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
                return [NSString stringWithFormat:NSLocalizedString(@"call_duration", nil), dict[@"CallTime"]];
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
