//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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

#import "ContactEntity.h"
#import "UserSettings.h"
#import "BaseMessage.h"
#import "ContactUtil.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static NSString *fieldTypingIndicators = @"typingIndicators";
static NSString *fieldReadReceipts = @"readReceipts";
static NSString *fieldImportStatus = @"importStatus";
static NSString *fieldHidden = @"hidden";

@implementation ContactEntity

@dynamic featureMask;
@dynamic firstName;
@dynamic identity;
@dynamic imageData;
@dynamic lastName;
@dynamic publicKey;
@dynamic publicNickname;
@dynamic sortIndex;
@dynamic sortInitial;
@dynamic verificationLevel;
@dynamic verifiedEmail;
@dynamic verifiedMobileNo;
@dynamic state;
@dynamic conversations;
@dynamic groupConversations;
@dynamic contactImage;
@dynamic profilePictureSended;
@dynamic profilePictureUpload;
@dynamic cnContactId;
@dynamic workContact;
@dynamic createdAt;
@dynamic profilePictureBlobID;
@dynamic forwardSecurityState;
@dynamic rejectedMessages;
@dynamic csi;
@dynamic jobTitle;
@dynamic department;

- (NSString *)displayName {
    NSMutableString *displayName = [ContactUtil nameFromFirstname:self.firstName lastname:self.lastName];
    
    if (displayName.length == 0 && self.publicNickname.length > 0 && [self.publicNickname isEqualToString:self.identity] == NO) {
        
        [displayName appendFormat:@"~%@", self.publicNickname];
    }
    
    if (displayName.length == 0 && self.identity != nil) {
        [displayName appendString:self.identity];
    }
    
    switch (self.state.intValue) {
        case kStateInactive:
            [displayName appendFormat:@" (%@)", [BundleUtil localizedStringForKey:@"inactive"]];
            break;
            
        case kStateInvalid:
            [displayName appendFormat:@" (%@)", [BundleUtil localizedStringForKey:@"invalid"]];
            break;
            
        default:
            break;
    }
    
    if (displayName == nil) {
        DDLogError(@"Display name is marked as nonnull and we should have something to show. Falling back to (unknown).");
        displayName = [[BundleUtil localizedStringForKey:@"(unknown)"] mutableCopy];
    }

    return displayName;
}

// This calls KVO observers of `displayName` if any of the provided key paths are called
// https://nshipster.com/key-value-observing/#automatic-property-notifications
+ (NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"firstName", @"lastName", @"publicNickname", @"identity", nil];
}

- (NSString *)mentionName {
    NSMutableString *mentionName = [ContactUtil nameFromFirstname:self.firstName lastname:self.lastName];
    
    if (mentionName.length == 0 && self.publicNickname.length > 0 && [self.publicNickname isEqualToString:self.identity] == NO) {
        [mentionName appendFormat:@"~%@", self.publicNickname];
    }
    
    if (mentionName.length == 0 && self.identity != nil) {
        [mentionName appendString:self.identity];
    }
    
    if (mentionName.length > 24) {
        mentionName = [NSMutableString stringWithFormat:@"%@...", [mentionName substringToIndex:24]];
    }
    return mentionName;
}

- (void)setFirstName:(NSString *)firstName {
    [self willChangeValueForKey:@"firstName"];
    [self setPrimitiveValue:firstName forKey:@"firstName"];
    [self updateSortInitial];
    [self didChangeValueForKey:@"firstName"];
}

- (void)setLastName:(NSString *)lastName {
    [self willChangeValueForKey:@"lastName"];
    [self setPrimitiveValue:lastName forKey:@"lastName"];
    [self updateSortInitial];
    [self didChangeValueForKey:@"lastName"];
}

- (void)setIdentity:(NSString *)identity {
    [self willChangeValueForKey:@"identity"];
    [self setPrimitiveValue:identity forKey:@"identity"];
    [self updateSortInitial];
    [self didChangeValueForKey:@"identity"];
}

- (BOOL)isContactHidden {
    return [self valueForKey:fieldHidden] != nil ? [[self valueForKey:fieldHidden] boolValue] : NO;
}

- (void)setIsContactHidden:(BOOL)isContactHidden {
    [self willChangeValueForKey:fieldHidden];
    [self setPrimitiveValue:[NSNumber numberWithBool:isContactHidden] forKey:fieldHidden];
    [self didChangeValueForKey:fieldHidden];
}

- (NSNumber *)featureMask {
    
    [self willAccessValueForKey:@"featureMask"];
    NSNumber *mask = [self primitiveValueForKey:@"featureMask"];
    [self didAccessValueForKey:@"featureMask"];
    
    return mask != nil ? mask : @0;
}

- (void)setFeatureMask:(NSNumber *)newFeatureMask {
    
    // If the new feature mask doesn't support FS anymore terminate all sessions with this contact (& post system
    // message if needed).
    // This prevents that old sessions get never deleted if a contact stops supporting FS, but a terminate is never
    // received.
    // This also prevents a race conditions where we try to establish a session with a contact that doesn't support FS
    // anymore, but the feature mask wasn't locally updated in the meantime. This new session might not be rejected or
    // terminated, because only `Encapsulated` (i.e. data) FS messages are rejected when FS is disabled.
    if (!(FEATURE_MASK_FORWARD_SECURITY & [newFeatureMask intValue])) {
        // Check if we actually used a FS session with this contact. If not we still terminate all sessions, but won't
        // post a system message
        BusinessInjector *businessInjector = [[BusinessInjector alloc] init];
        ForwardSecurityContact *fsContact = [[ForwardSecurityContact alloc] initWithIdentity:[self identity] publicKey:[self publicKey]];
        BOOL hasUsedForwardSecurity = [[businessInjector fsmp] hasContactUsedForwardSecurityWithContact:fsContact];
        
        // Terminate sessions
        // If the contact really disabled FS it won't process the terminate, but we send it anyway just to be sure
        [ForwardSecuritySessionTerminatorObjC terminateAllSessionsWithDisabledByRemoteFor:self completion:^(BOOL deletedAnySession) {
            // Post system message only if we received a FS message in this session, any sessions were terminated and a
            // conversation with this contact exists
            if (hasUsedForwardSecurity && deletedAnySession && [self.conversations count] > 0) {
                [self postPFSNotSupportedSystemMessage];
            }
        } error:^(NSError * _Nonnull error) {
            DDLogError(@"Failed to terminate sessions on downgraded feature mask: %@", error);
        }];
        
        // We will continue even if termination hasn't completed...
    }
    
    // Only update feature mask if actually changed. This prevents that the CD-entity is updated even though the value
    // didn't change.
    if (self.featureMask.intValue == newFeatureMask.intValue) {
        DDLogNotice(@"Don't set new feature mask as it didn't change.");
        return;
    }
    
    [self willChangeValueForKey:@"featureMask"];
    [self setPrimitiveValue:newFeatureMask != nil ? newFeatureMask : @0 forKey:@"featureMask"];
    [self didChangeValueForKey:@"featureMask"];
}

- (void)postPFSNotSupportedSystemMessage {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        ConversationEntity *conversation = [[entityManager entityFetcher] conversationEntityForContact:self];
        if (conversation != nil) {
            SystemMessageEntity *systemMessage = [entityManager.entityCreator systemMessageEntityForConversationEntity:conversation];
            systemMessage.type = [NSNumber numberWithInt:kSystemMessageFsNotSupportedAnymore];
            systemMessage.remoteSentDate = [NSDate date];
            if (systemMessage.isAllowedAsLastMessage) {
                conversation.lastMessage = systemMessage;
            }
        }
    }];
}

- (TypingIndicator)typingIndicator {
    if ([self valueForKey:fieldTypingIndicators] != nil) {
        switch ([[self valueForKey:fieldTypingIndicators] intValue]) {
            case 1:
                return TypingIndicatorSend;
            case 2:
                return TypingIndicatorDoNotSend;
            default:
                return TypingIndicatorDefault;
        }
    }
    return TypingIndicatorDefault;
}

// This calls KVO observers of `typingIndicator` if any of the provided key paths are called
// https://nshipster.com/key-value-observing/#automatic-property-notifications
+ (NSSet *)keyPathsForValuesAffectingTypingIndicator {
    return [NSSet setWithObjects:fieldTypingIndicators, nil];
}

- (void)setTypingIndicator:(TypingIndicator)typingIndicator {
    [self willChangeValueForKey:fieldTypingIndicators];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)typingIndicator] forKey:fieldTypingIndicators];
    [self didChangeValueForKey:fieldTypingIndicators];
}

- (ReadReceipt)readReceipt {
    if ([self valueForKey:fieldReadReceipts] != nil) {
        switch ([[self valueForKey:fieldReadReceipts] intValue]) {
            case 1:
                return ReadReceiptSend;
            case 2:
                return ReadReceiptDoNotSend;
            default:
                return ReadReceiptDefault;
        }
    }
    return ReadReceiptDefault;
}

// This calls KVO observers of `readReceipt` if any of the provided key paths are called
// https://nshipster.com/key-value-observing/#automatic-property-notifications
+ (NSSet *)keyPathsForValuesAffectingReadReceipt {
    return [NSSet setWithObjects:fieldReadReceipts, nil];
}

- (void)setReadReceipt:(ReadReceipt)readReceipt {
    [self willChangeValueForKey:fieldReadReceipts];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)readReceipt] forKey:fieldReadReceipts];
    [self didChangeValueForKey:fieldReadReceipts];
}

- (ImportedStatus)importedStatus {
    if ([self valueForKey:fieldImportStatus] != nil) {
        switch ([[self valueForKey:fieldImportStatus] intValue]) {
            case 0:
                return ImportedStatusInitial;
            case 1:
                return ImportedStatusImported;
            case 2:
                return ImportedStatusCustom;
            default:
                return ImportedStatusInitial;
        }
    }
    return ImportedStatusInitial;
}

- (void)setImportedStatus:(ImportedStatus)importedStatus {
    [self willChangeValueForKey:fieldImportStatus];
    [self setPrimitiveValue:[NSNumber numberWithInt:(int)importedStatus] forKey:fieldImportStatus];
    [self didChangeValueForKey:fieldImportStatus];
}

- (BOOL)isActive {
    return (self.state.intValue == kStateActive);
}

- (BOOL)isValid {
    return (self.state.intValue != kStateInvalid);
}

- (void)setImageData:(NSData *)imageData {
    [self willChangeValueForKey:@"imageData"];
    [self setPrimitiveValue:imageData forKey:@"imageData"];
    [self didChangeValueForKey:@"imageData"];
}

- (void)setContactImage:(ImageDataEntity *)contactImage {
    [self willChangeValueForKey:@"contactImage"];
    [self setPrimitiveValue:contactImage forKey:@"contactImage"];
    [self didChangeValueForKey:@"contactImage"];
}

- (BOOL)isGatewayId {
    return [self.identity hasPrefix:@"*"];
}

- (BOOL)isEchoEcho {
    return [self.identity isEqualToString:@"ECHOECHO"];
}

- (BOOL)isProfilePictureSended {
    return self.profilePictureSended;
}

// This only means it's a verified contact from the admin (in the same work package)
// To check if this contact is a work ID, use the workidentities list in usersettings
// bad naming because of the history...
- (BOOL)isWorkContact {
    return self.workContact.boolValue;
}

- (int)workAdjustedVerificationLevel {
    int myVerificationLevel = self.verificationLevel.intValue;
    if ([self isWorkContact]) {
        if (myVerificationLevel == kVerificationLevelServerVerified || myVerificationLevel == kVerificationLevelFullyVerified) {
            myVerificationLevel += 2;
        } else {
            myVerificationLevel = kVerificationLevelWorkVerified;
        }
    }
    
    return myVerificationLevel;
}

- (UIImage*)verificationLevelImageSmall {
    int myVerificationLevel = [self workAdjustedVerificationLevel];
    switch (myVerificationLevel) {
        case 0:
            return [StyleKit verificationSmall0];
        case 1:
            return [StyleKit verificationSmall1];
        case 2:
            return [StyleKit verificationSmall2];
        case 3:
            return [StyleKit verificationSmall3];
        case 4:
            return [StyleKit verificationSmall4];
        default:
            return [StyleKit verificationSmall0];
    }
}

- (UIImage*)verificationLevelImage {
    int myVerificationLevel = [self workAdjustedVerificationLevel];
    switch (myVerificationLevel) {
        case 0:
            return [StyleKit verification0];
        case 1:
            return [StyleKit verification1];
        case 2:
            return [StyleKit verification2];
        case 3:
            return [StyleKit verification3];
        case 4:
            return [StyleKit verification4];
        default:
            return [StyleKit verification0];
    }
}

- (UIImage*)verificationLevelImageBig {
    int myVerificationLevel = [self workAdjustedVerificationLevel];
    switch (myVerificationLevel) {
        case 0:
            return [StyleKit verificationBig0];
        case 1:
            return [StyleKit verificationBig1];
        case 2:
            return [StyleKit verificationBig2];
        case 3:
            return [StyleKit verificationBig3];
        case 4:
            return [StyleKit verificationBig4];
        default:
            return [StyleKit verificationBig0];
    }
}

- (NSString*)verificationLevelAccessibilityLabel {
    int myVerificationLevel = [self workAdjustedVerificationLevel];
    
    NSString *localizationString = [NSString stringWithFormat:@"level%d_title", myVerificationLevel];
    
    return [BundleUtil localizedStringForKey:localizationString];
}

- (BOOL)isVideoCallAvailable {
    return [self.featureMask integerValue] & FEATURE_MASK_VOIP_VIDEO;
}

- (BOOL)isForwardSecurityAvailable {
    return [self.featureMask integerValue] & FEATURE_MASK_FORWARD_SECURITY;
}

@end
