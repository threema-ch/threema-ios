//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

#import <Foundation/Foundation.h>
#import "BaseMessage.h"

typedef NS_ENUM(NSInteger, PushSettingType) {
    kPushSettingTypeOn = 0,
    kPushSettingTypeOff,
    kPushSettingTypeOffPeriod
};

typedef NS_ENUM(NSInteger, PeriodOffTime) {
    kPeriodOffTime1Hour = 0,
    kPeriodOffTime2Hours = 1,
    kPeriodOffTime3Hours = 2,
    kPeriodOffTime4Hours = 3,
    kPeriodOffTime8Hours = 4,
    kPeriodOffTime1Day = 5,
    kPeriodOffTime1Week = 6
};

@interface PushSetting : NSObject

@property (nonatomic, strong) NSString *identity;

@property (nonatomic) PushSettingType type;
@property (nonatomic) PeriodOffTime periodOffTime;
@property (nonatomic, strong) NSDate *periodOffTillDate;

@property (nonatomic) BOOL silent;
@property (nonatomic) BOOL mentions;

+ (PushSetting *)findPushSettingForIdentity:(NSString *)identity pushSettingList:(NSOrderedSet *)pushSettingList;
+ (PushSetting *)findPushSettingForConversation:(Conversation *)conversation;
+ (NSDictionary *)findPushSettingDictForIdentity:(NSString *)identity;
+ (NSDictionary *)findPushSettingDictForConversation:(Conversation *)conversation;
+ (PushSetting *)findPushSettingForIdentity:(NSString *)identity;
+ (PushSetting *)findPushSettingForGroupId:(NSData *)groupId;

- (id)initWithDictionary:(NSDictionary *)dict;

- (NSDictionary *)buildDict;
- (BOOL)canSendPushForBaseMessage:(BaseMessage *)baseMessage;
- (BOOL)canSendPush;
- (UIImage *)imageForEditedPushSetting;
- (UIImage *)imageForPushSetting;

@end
