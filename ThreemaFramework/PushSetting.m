//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

#import "PushSetting.h"
#import "Conversation.h"
#import "NSString+Hex.h"
#import "Contact.h"
#import "UserSettings.h"
#import "TextStyleUtils.h"

@implementation PushSetting

+ (PushSetting *)findPushSettingForConversation:(Conversation *)conversation {
    NSDictionary *dict = nil;
    if (conversation.isGroup) {
        dict = [PushSetting findPushSettingDictForIdentity:[NSString stringWithHexData:conversation.groupId]];
    } else {
        dict = [PushSetting findPushSettingDictForIdentity:conversation.contact.identity];
    }
    
    if (dict != nil) {
        return [[PushSetting alloc] initWithDictionary:dict];
    }
    
    return nil;
}

+ (NSDictionary *)findPushSettingDictForConversation:(Conversation *)conversation {
    if (conversation.isGroup) {
        return [PushSetting findPushSettingDictForIdentity:[NSString stringWithHexData:conversation.groupId]];
    } else {
        return [PushSetting findPushSettingDictForIdentity:conversation.contact.identity];
    }
}

+ (NSDictionary *)findPushSettingDictForIdentity:(NSString *)identity {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identity == %@", identity];
    NSOrderedSet *settingsArray = [[[UserSettings sharedUserSettings] pushSettingsList] filteredOrderedSetUsingPredicate:predicate];
    if (settingsArray.count > 0) {
        return settingsArray.firstObject;
    }
    
    return nil;
}

+ (PushSetting *)findPushSettingForIdentity:(NSString *)identity {
    NSDictionary *dict = [PushSetting findPushSettingDictForIdentity:identity];
    
    if (dict != nil) {
        return [[PushSetting alloc] initWithDictionary:dict];
    }
    
    return nil;
}

+ (PushSetting *)findPushSettingForIdentity:(NSString *)identity pushSettingList:(NSOrderedSet *)pushSettingList {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identity == %@", identity];
    NSOrderedSet *settingsArray = [pushSettingList filteredOrderedSetUsingPredicate:predicate];
    if (settingsArray.count > 0) {
        return [[PushSetting alloc] initWithDictionary:settingsArray.firstObject];
    }
    
    return nil;
}

+ (PushSetting *)findPushSettingForGroupId:(NSData *)groupId {
    NSDictionary *dict = [PushSetting findPushSettingDictForIdentity:[NSString stringWithHexData:groupId]];
    
    if (dict != nil) {
        return [[PushSetting alloc] initWithDictionary:dict];
    }
    
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dict {
    self=[super init];
    if (self) {
        self.identity = dict[@"identity"];
        self.type = [dict[@"type"] integerValue];
        self.periodOffTime = [dict[@"periodOffTime"] integerValue];
        self.periodOffTillDate = dict[@"periodOffTillDate"];
        self.silent = [dict[@"silent"] boolValue];
        self.mentions = [dict[@"mentions"] boolValue];
    }
    return self;
}

- (NSDictionary *)buildDict {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (self.identity != nil){
        [dict setObject:self.identity forKey:@"identity"];
    }
    [dict setObject:[NSNumber numberWithInteger:self.type] forKey:@"type"];
    if (self.periodOffTime != 0) {
        [dict setObject:[NSNumber numberWithInteger:self.periodOffTime] forKey:@"periodOffTime"];
    }
    if (self.periodOffTillDate != nil) {
        [dict setObject:self.periodOffTillDate forKey:@"periodOffTillDate"];
    }
    [dict setObject:[NSNumber numberWithBool:self.silent] forKey:@"silent"];
    [dict setObject:[NSNumber numberWithBool:self.mentions] forKey:@"mentions"];
    
    return dict;
}

- (BOOL)canSendPushForBaseMessage:(BaseMessage *)baseMessage {
    if (self.type == kPushSettingTypeOff) {
        if (self.mentions && baseMessage.conversation.isGroup) {
            if (![TextStyleUtils isMeOrAllMentionInText:[baseMessage logText]]) {
                return NO;
            }
        } else {
            return NO;
        }
    }
    else if (self.type == kPushSettingTypeOffPeriod) {
        if ([self.periodOffTillDate compare:[NSDate date]] == NSOrderedDescending) {
            if (self.mentions && baseMessage.conversation.isGroup) {
                if (![TextStyleUtils isMeOrAllMentionInText:[baseMessage logText]]) {
                    return NO;
                }
            } else {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)canSendPush {
    if (self.type == kPushSettingTypeOff) {
        return NO;
    }
    else if (self.type == kPushSettingTypeOffPeriod) {
        if ([self.periodOffTillDate compare:[NSDate date]] == NSOrderedDescending) {
            return NO;
        }
    }
    return YES;
}
    
- (UIImage *)imageForPushSetting {
    UIImage *pushSettingIcon = [self imageForEditedPushSetting];
    if (pushSettingIcon == nil) {
        pushSettingIcon = [UIImage imageNamed:@"Bell"];
    }
    return pushSettingIcon;
}

- (UIImage *)imageForEditedPushSetting {
    UIImage *pushSettingIcon = nil;
    
    if (self.type == kPushSettingTypeOn && self.silent) {
        pushSettingIcon = [UIImage imageNamed:@"BellOff"];
    }
    else if (self.type == kPushSettingTypeOff && !self.mentions) {
        pushSettingIcon = [UIImage imageNamed:@"NotificationOff"];
    }
    else if (self.type == kPushSettingTypeOff && self.mentions) {
        pushSettingIcon = [UIImage imageNamed:@"At"];
    }
    else if (self.type == kPushSettingTypeOffPeriod && !self.mentions && [self.periodOffTillDate compare:[NSDate date]] == NSOrderedDescending) {
        pushSettingIcon = [UIImage imageNamed:@"NotificationOff"];
    }
    else if (self.type == kPushSettingTypeOffPeriod && self.mentions && [self.periodOffTillDate compare:[NSDate date]] == NSOrderedDescending) {
        pushSettingIcon = [UIImage imageNamed:@"At"];
    }
    
    return pushSettingIcon;
}

@end
