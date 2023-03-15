//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
#import "ContactEntity.h"
#import "UserSettings.h"
#import "TextStyleUtils.h"

#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation PushSetting

@synthesize type = _type;

#pragma mark - Class methods

+ (PushSetting *)pushSettingForConversation:(Conversation *)conversation {
    return [PushSetting pushSettingForIdentity:[PushSetting identityForConversation:conversation]];
}

+ (PushSetting *)pushSettingForContact:(ContactEntity *)contact {
    return [PushSetting pushSettingForIdentity:[PushSetting identityForContact:contact]];
}

+ (PushSetting *)pushSettingForThreemaId:(NSString *)threemaId {
    return [PushSetting pushSettingForIdentity:threemaId];
}

+ (PushSetting *)pushSettingForGroupId:(NSData *)groupId {
    return [PushSetting pushSettingForIdentity:[PushSetting identityForGroupId:groupId]];
}

#pragma mark Internal class methods

+ (NSString *)identityForConversation:(Conversation *)conversation {
    if (conversation.isGroup) {
        return [PushSetting identityForGroupId:conversation.groupId];
    } else {
        return [PushSetting identityForContact:conversation.contact];
    }
}

+ (NSString *)identityForContact:(ContactEntity *)contact {
    return contact.identity;
}

+ (NSString *)identityForGroupId:(NSData *)groupId {
    return [NSString stringWithHexData:groupId];
}

+ (PushSetting *)pushSettingForIdentity:(NSString *)identity {
    NSOrderedSet *pushSettings = [UserSettings sharedUserSettings].pushSettingsList;
    
    NSDictionary *foundSetting = [PushSetting findExistingPushSettingDictForIdentity:identity pushSettingList:pushSettings];
    
    if (foundSetting) {
        return [[PushSetting alloc] initWithDictionary:foundSetting];
    } else {
        // Create new default setting if it doesn't exist
        return [[PushSetting alloc] initWithIdentity:identity];
    }
}

+ (nullable NSDictionary *)findExistingPushSettingDictForIdentity:(NSString *)identity pushSettingList:(NSOrderedSet *)pushSettingList {
    NSOrderedSet *orderedSet = [PushSetting findExistingPushSettingDictsForIdentity:identity pushSettingList:pushSettingList];
    
    if (orderedSet.count > 0) {
        return orderedSet.firstObject;
    }
    
    return nil;
}

+ (NSOrderedSet<NSDictionary *> *)findExistingPushSettingDictsForIdentity:(NSString *)identity pushSettingList:(NSOrderedSet *)pushSettingList {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identity == %@", identity];
    NSOrderedSet *filteredSettings = [pushSettingList filteredOrderedSetUsingPredicate:predicate];
   
    return filteredSettings;
}

#pragma mark - Initialization

- (id)initWithIdentity:(NSString *)identity {
    self = [super init];
    
    if (self) {
        self.identity = identity;
        self.type = kPushSettingTypeOn;
        self.periodOffTime = kPeriodOffTime1Hour;
        self.periodOffTillDate = nil;
        self.silent = NO;
        self.mentions = NO;
    } else {
        // This allows us to guarantee nonnull return values
        [NSException raise:@"Fatal Error" format:@"PushSetting should always be nonnull."];
    }
    
    return self;
}

// Publicly deprecated, but needed for internal implementation
- (id)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    
    if (self) {
        self.identity = dict[@"identity"];
        self.type = [dict[@"type"] integerValue];
        self.periodOffTime = [dict[@"periodOffTime"] integerValue];
        self.periodOffTillDate = dict[@"periodOffTillDate"];
        self.silent = [dict[@"silent"] boolValue];
        self.mentions = [dict[@"mentions"] boolValue];
    } else {
        // This allows us to guarantee nonnull return values
        [NSException raise:@"Fatal Error" format:@"PushSetting should always be nonnull."];
    }
    
    return self;
}

#pragma mark - Getters

- (PushSettingType)type {
    
    // Housekeeping: Ensure that `type` is only `kPushSettingTypeOffPeriod` if a `periodOffTillDate`
    // is set and it is in the future
    if (_type == kPushSettingTypeOffPeriod) {
        if (self.periodOffTillDate == nil) {
            _type = kPushSettingTypeOn;
            
        // This should be the only needed date comparison in all of this class
        } else if ([self.periodOffTillDate compare:[NSDate date]] == NSOrderedAscending) {
            _type = kPushSettingTypeOn;
            self.periodOffTillDate = nil;
        }
    }
    
    return _type;
}

- (NSString *)localizedDescription {
    NSString *formatString = [BundleUtil localizedStringForKey:@"doNotDisturb_on_until_date_and_time"];
    
    return [self localizedDescriptionWithOffPeriodFormatString:formatString];
}

- (NSString *)localizedLongDescription {
    NSString *formatString = [BundleUtil localizedStringForKey:@"doNotDisturb_on_until_date_and_time_long"];
    
    return [self localizedDescriptionWithOffPeriodFormatString:formatString];
}

// Helper for the previous two getters
// This method should always be internal and a caller has to ensure that `offPeriodFormatString` is
// not controllable by the user or any remote user, because it is a format string.
- (NSString *)localizedDescriptionWithOffPeriodFormatString:(NSString *)offPeriodFormatString {
    NSString *description = @"";
    
    if (self.type == kPushSettingTypeOffPeriod) {
        NSString *formattedDateAndTime = [DateFormatter relativeLongStyleDateShortStyleTime:self.periodOffTillDate];
        description = [NSString stringWithFormat:offPeriodFormatString, formattedDateAndTime];
    } else if (self.type == kPushSettingTypeOff) {
        description = [BundleUtil localizedStringForKey:@"doNotDisturb_on"];
    } else if (self.type == kPushSettingTypeOn) {
        description = [BundleUtil localizedStringForKey:@"doNotDisturb_off"];
    }
    
    return description;
}

- (nonnull NSString *)sfSymbolNameForPushSetting {
    NSString *sfSymbolName = self.sfSymbolNameForEditedPushSetting;
    
    if (sfSymbolName == nil) {
        sfSymbolName = @"bell.fill";
    }
    
    return sfSymbolName;
}

- (nullable NSString *)sfSymbolNameForEditedPushSetting {
    NSString *sfSymbolName = nil;
    
    if (!self.mentions && (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff)) {
        sfSymbolName = @"minus.circle.fill";
    } else if (self.mentions && (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff)) {
        sfSymbolName = @"at.circle.fill";
    } else if (self.silent && self.type == kPushSettingTypeOn) {
        sfSymbolName = @"bell.slash.fill";
    }
    
    return sfSymbolName;
}

#pragma mark - Setters

- (void)setIdentity:(NSString * _Nullable)identity {
    _identity = identity;
}

- (void)setType:(PushSettingType)type {
    _type = type;
    
    if (type == kPushSettingTypeOn || type == kPushSettingTypeOff) {
        self.periodOffTillDate = nil;
    }
}

- (void)setPeriodOffTime:(PeriodOffTime)periodOffTime {
    // We cannot automatically set `_type` here, because there is not "off" `PeriodOffTime`.
    _periodOffTime = periodOffTime;
    
    // Automatically set expiration date
    switch (periodOffTime) {
        case kPeriodOffTime1Hour:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitHour
                                      value:1
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
        
        case kPeriodOffTime2Hours:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitHour
                                      value:2
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
        case kPeriodOffTime3Hours:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitHour
                                      value:3
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
        case kPeriodOffTime4Hours:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitHour
                                      value:4
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
            
        case kPeriodOffTime8Hours:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitHour
                                      value:8
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
        case kPeriodOffTime1Day:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitDay
                                      value:1
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
        case kPeriodOffTime1Week:
            self.periodOffTillDate = [NSCalendar.currentCalendar
                                      dateByAddingUnit:NSCalendarUnitWeekOfMonth
                                      value:1
                                      toDate:[NSDate date]
                                      options:NSCalendarMatchFirst];
            break;
            
        default:
            NSAssert(false, @"Unknown case");
            break;
    }
}

- (void)setPeriodOffTillDate:(NSDate * _Nullable)periodOffTillDate {
    _periodOffTillDate = periodOffTillDate;
}

#pragma mark - Instance methods

- (void)save {
    NSMutableOrderedSet *pushSettings = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].pushSettingsList];
    
    // Remove existing entries for this id
    NSOrderedSet *existingEntries = [PushSetting findExistingPushSettingDictsForIdentity:self.identity pushSettingList:pushSettings];
    for (NSDictionary *entry in existingEntries) {
        [pushSettings removeObject:entry];
    }
    
    // Add new entry for this id
    [pushSettings addObject:[self buildDict]];
    
    [[UserSettings sharedUserSettings] setPushSettingsList:pushSettings];
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
    if (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff) {
        if (self.mentions && baseMessage.conversation.isGroup) {
            if (![TextStyleUtils isMeOrAllMentionInText:[baseMessage logText]]) {
                return NO;
            }
        } else {
            return NO;
        }
    }
    return YES;
}

- (BOOL)canSendPush {
    if (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff) {
        return NO;
    }
    return YES;
}
    
- (UIImage *)imageForPushSetting {
    UIImage *pushSettingIcon = [self imageForEditedPushSettingWith:nil];
    if (pushSettingIcon == nil) {
        pushSettingIcon = [UIImage imageNamed:@"Bell"];
    }
    return pushSettingIcon;
}

- (UIImage * _Nullable)imageForEditedPushSettingWith:( UIImageConfiguration * _Nullable )config {
    UIImage *pushSettingIcon = nil;
    
    if (!self.mentions && (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff)) {
        pushSettingIcon = [UIImage systemImageNamed:@"minus.circle.fill" withConfiguration:config];
    }
    else if (self.mentions && (self.type == kPushSettingTypeOffPeriod || self.type == kPushSettingTypeOff)) {
        pushSettingIcon = [UIImage systemImageNamed:@"at.circle.fill" withConfiguration:config];
    }
    else if (self.type == kPushSettingTypeOn && self.silent) {
        pushSettingIcon = [UIImage systemImageNamed:@"bell.slash.circle.fill" withConfiguration:config];
    }
    
    return pushSettingIcon;
}

#pragma mark - Setup or migration

+ (void)addDefaultSettingForElementsWithoutSettingInConversations:(NSArray<Conversation *> *)conversations {
    NSMutableOrderedSet *pushSettings = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].pushSettingsList];
    
    for (Conversation *conversation in conversations) {
        NSString *identity = [PushSetting identityForConversation:conversation];
        NSDictionary *pushSettingDictionary = [PushSetting findExistingPushSettingDictForIdentity:identity pushSettingList:pushSettings];
        
        if (pushSettingDictionary == nil) {
            PushSetting *tmpPushSetting = [[PushSetting alloc] initWithIdentity:identity];
            [pushSettings addObject:tmpPushSetting.buildDict];
        }
    }
    
    [[UserSettings sharedUserSettings] setPushSettingsList:pushSettings];
}

+ (void)addPushSettingsForNoPushIdentities:(NSOrderedSet<NSString *> *)noPushIdentities {
    NSMutableOrderedSet *pushSettings = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].pushSettingsList];
    
    for (NSString *identity in noPushIdentities.array) {
        NSDictionary *pushSettingDictionary = [PushSetting findExistingPushSettingDictForIdentity:identity pushSettingList:pushSettings];
        
        PushSetting *tmpPushSetting;
        
        if (pushSettingDictionary == nil) {
            tmpPushSetting = [[PushSetting alloc] initWithIdentity:identity];
        } else {
            [pushSettings removeObject:pushSettingDictionary];
            tmpPushSetting = [[PushSetting alloc] initWithDictionary:pushSettingDictionary];
        }
        
        tmpPushSetting.type = kPushSettingTypeOff;
        [pushSettings addObject:tmpPushSetting.buildDict];
    }
    
    [[UserSettings sharedUserSettings] setPushSettingsList:pushSettings];
}

@end
