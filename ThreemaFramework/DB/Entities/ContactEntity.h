//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "TMAManagedObject.h"

@class BaseMessage, Conversation, ImageData;

typedef NS_CLOSED_ENUM(NSInteger, TypingIndicator) {
    TypingIndicatorDefault = 0,
    TypingIndicatorSend = 1,
    TypingIndicatorDoNotSend = 2
};

typedef NS_CLOSED_ENUM(NSInteger, ReadReceipt) {
    ReadReceiptDefault = 0,
    ReadReceiptSend = 1,
    ReadReceiptDoNotSend = 2
};

typedef NS_CLOSED_ENUM(NSInteger, ImportedStatus) {
    ImportedStatusInitial = 0,
    ImportedStatusImported = 1,
    ImportedStatusCustom = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface ContactEntity : TMAManagedObject

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

// Properties DB
@property (nonatomic, retain, nullable) NSNumber * abRecordId NS_SWIFT_NAME(abRecordID);
@property (nonatomic, retain, nullable) NSString * cnContactId NS_SWIFT_NAME(cnContactID);
@property (nonatomic, retain, nullable) NSDate * createdAt;
@property (nonatomic, retain, nullable) NSString * firstName;
@property (nonatomic, retain) NSString * identity;
@property (nonatomic, retain, nullable) NSData * imageData;
@property (nonatomic, retain, nullable) NSString * lastName;
@property (nonatomic, retain) NSData * publicKey;
@property (nonatomic, retain, nullable) NSString * publicNickname;
@property (nonatomic, retain, nullable) NSString * profilePictureBlobID;
@property (nonatomic) BOOL profilePictureSended;
@property (nonatomic, retain, nullable) NSDate * profilePictureUpload;
@property (nonatomic, retain, nullable) NSNumber * sortIndex;
@property (nonatomic, retain, nullable) NSString * sortInitial;
@property (nonatomic, retain, nullable) NSNumber * state;
@property (nonatomic, retain) NSNumber * verificationLevel;
@property (nonatomic, retain, nullable) NSString * verifiedEmail;
@property (nonatomic, retain, nullable) NSString * verifiedMobileNo;
/// This only means it's a verified contact from the admin (in the same work package). To check if this contact is a work ID, use the work identities list in user settings bad naming because of the history...
@property (nonatomic, retain) NSNumber * workContact;
/// Set or Get the forward security state of this contact. Note that these states are only maintained for contacts with a DH session of version 1.0.
/// TODO(ANDR-2452): Remove the forward security state when most of clients support 1.1 anyway
@property (nonatomic, retain) NSNumber * forwardSecurityState;

// MARK: - DB Relationships

@property (nonatomic, retain, nullable) ImageData * contactImage;
@property (nonatomic, retain, nullable) NSSet * conversations;
@property (nonatomic, retain, nullable) NSSet * groupConversations;

/// All (group) messages that where rejected by this contact
///
/// The inverse is `rejectedBy` of `BaseMessage`.
@property (nonatomic, retain, nullable) NSSet<BaseMessage *> *rejectedMessages;

// MARK: - Other Properties

@property (readonly) NSString * displayName;
@property (readonly) NSString * mentionName;
@property (nonatomic) BOOL isContactHidden;
@property (nonatomic) NSNumber * featureMask;
@property (nonatomic) TypingIndicator typingIndicator;
@property (nonatomic) ReadReceipt readReceipt;
@property (nonatomic) ImportedStatus importedStatus;


- (void)updateSortInitial;

- (BOOL)isActive;

- (BOOL)isValid;

- (BOOL)isGatewayId NS_SWIFT_NAME(isGatewayID());

- (BOOL)isEchoEcho;

- (BOOL)isProfilePictureSended;

- (BOOL)isProfilePictureSet;

- (BOOL)isWorkContact;

- (UIImage*)verificationLevelImageSmall;
- (UIImage*)verificationLevelImage;
- (UIImage*)verificationLevelImageBig;
/// Localized string of verification level usable for accessibility
- (NSString*)verificationLevelAccessibilityLabel;

- (BOOL)isVideoCallAvailable;
- (BOOL)isForwardSecurityAvailable;

@end

NS_ASSUME_NONNULL_END

@interface ContactEntity (CoreDataGeneratedAccessors)

- (void)addConversationsObject:(nullable Conversation *)value;
- (void)removeConversationsObject:(nullable Conversation *)value;
- (void)addConversations:(nullable NSSet *)values;
- (void)removeConversations:(nullable NSSet *)values;

- (void)addGroupConversationsObject:(nullable Conversation *)value;
- (void)removeGroupConversationsObject:(nullable Conversation *)value;
- (void)addGroupConversations:(nullable NSSet *)values;
- (void)removeGroupConversations:(nullable NSSet *)values;

@end
