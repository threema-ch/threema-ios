//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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
#import <CoreData/CoreData.h>

@class BaseMessage, Conversation, ImageData;

@interface Contact : NSManagedObject

enum {
    kVerificationLevelUnverified = 0,
    kVerificationLevelServerVerified,
    kVerificationLevelFullyVerified,
    kVerificationLevelWorkVerified,         // Legacy value, do not use anymore except for migration. Use workContact instead
    kVerificationLevelWorkFullyVerified     // Legacy value, do not use anymore except for migration. Use workContact instead
};

enum {
    kStateActive = 0,
    kStateInactive = 1,
    kStateInvalid = 2
};

@property (nonatomic, retain) NSNumber * abRecordId;
@property (nonatomic, retain) NSNumber * featureLevel;
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * identity;
@property (nonatomic, retain) NSData * imageData;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSData * publicKey;
@property (nonatomic, retain) NSString * publicNickname;
@property (nonatomic, retain) NSNumber * sortIndex;
@property (nonatomic, retain) NSString * sortInitial;
@property (nonatomic, retain) NSNumber * verificationLevel;
@property (nonatomic, retain) NSString * verifiedEmail;
@property (nonatomic, retain) NSString * verifiedMobileNo;
@property (nonatomic, retain) NSNumber * state;
@property (nonatomic, retain) NSSet *conversations;
@property (nonatomic, retain) NSSet *groupConversations;
@property (nonatomic, retain) NSSet *messages;
@property (nonatomic, retain) ImageData *contactImage;
@property (nonatomic) BOOL profilePictureSended;
@property (nonatomic, retain) NSDate *profilePictureUpload;
@property (nonatomic, retain) NSString *cnContactId;

// This only means it's a verified contact from the admin (in the same work package)
// To check if this contact is a work ID, use the workidentities list in usersettings
// bad naming because of the history...
@property (nonatomic, retain) NSNumber * workContact;
@property (nonatomic, retain) NSNumber * hidden;

@property (readonly) NSString* displayName;
@property (readonly) NSString *mentionName;

- (void)updateSortInitial;

- (BOOL)isActive;

- (BOOL)isValid;

- (BOOL)isGatewayId;

- (BOOL)isEchoEcho;

- (BOOL)isProfilePictureSended;

- (BOOL)isProfilePictureSet;

- (void)setFeatureMask:(NSNumber *)featureMask;
- (NSNumber *)featureMask;

- (BOOL)isWorkContact;

- (UIImage*)verificationLevelImageSmall;
- (UIImage*)verificationLevelImage;
- (UIImage*)verificationLevelImageBig;
/// Localized string of verification level usable for accessibility
- (NSString*)verificationLevelAccessibilityLabel;

- (BOOL)isVideoCallAvailable;

@end

@interface Contact (CoreDataGeneratedAccessors)

- (void)addConversationsObject:(Conversation *)value;
- (void)removeConversationsObject:(Conversation *)value;
- (void)addConversations:(NSSet *)values;
- (void)removeConversations:(NSSet *)values;

- (void)addGroupConversationsObject:(Conversation *)value;
- (void)removeGroupConversationsObject:(Conversation *)value;
- (void)addGroupConversations:(NSSet *)values;
- (void)removeGroupConversations:(NSSet *)values;

- (void)addMessagesObject:(BaseMessage *)value;
- (void)removeMessagesObject:(BaseMessage *)value;
- (void)addMessages:(NSSet *)values;
- (void)removeMessages:(NSSet *)values;

@end
