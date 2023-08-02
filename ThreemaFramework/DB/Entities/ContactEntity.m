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

#import "ContactEntity.h"
#import "Conversation.h"
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
static NSString *fieldFeatureLevel = @"featureLevel";

@implementation ContactEntity

@dynamic abRecordId;
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

// TODO: This will only be used after IOS-1495 has been merged and database model v30 has been actived.
//@dynamic abFirstName;
//@dynamic abLastName;
//@dynamic importStatus;


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

- (void)updateSortInitial {
    SEL stringSelector;
    if (self.isGatewayId) {
        stringSelector = @selector(identity);
    } else {
        if ([UserSettings sharedUserSettings].sortOrderFirstName) {
            if (self.firstName.length > 0) {
                stringSelector = @selector(firstName);
            } else if (self.lastName.length > 0) {
                stringSelector = @selector(lastName);
            } else if (self.publicNickname.length > 0) {
                stringSelector = @selector(publicNickname);
            } else {
                stringSelector = @selector(identity);
            }
        } else {
            if (self.lastName.length > 0) {
                stringSelector = @selector(lastName);
            } else if (self.firstName.length > 0) {
                stringSelector = @selector(firstName);
            } else if (self.publicNickname.length > 0) {
                stringSelector = @selector(publicNickname);
            } else {
                stringSelector = @selector(identity);
            }
        }
    }
    
    NSInteger idx = [[UILocalizedIndexedCollation currentCollation] sectionForObject:self collationStringSelector:stringSelector];
    
    NSString *sortInitial = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:idx];
    NSNumber *sortIndex = [NSNumber numberWithInteger:idx];
    
    if ([self.sortInitial isEqualToString:sortInitial] == NO) {
        self.sortInitial = sortInitial;
    }

    if ([self.sortIndex isEqualToNumber:sortIndex] == NO) {
        self.sortIndex = sortIndex;
    }
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
    return [self valueForKey:fieldFeatureLevel] != nil ? (NSNumber *)[self valueForKey:fieldFeatureLevel] : @0;
}

- (void)setFeatureMask:(NSNumber *)featureMask {
    // Post a system message if we have an existing chat and enabled PFS for this contact
    // but he has downgraded to a version which does not yet support PFS.
    // This can happen in regular operation for example when someone switches between the release version
    // and the multi device beta.
    // This is tracked as part of SE-267
    if ([self.conversations count] > 0) {
        if ((FEATURE_MASK_FORWARD_SECURITY & [self.featureMask intValue])) {
            // Old value had forward security
            if (!(FEATURE_MASK_FORWARD_SECURITY & [featureMask intValue])) {
                // New value does not have forward security
                
                // Post system message only if a session with this contact exists
                BusinessInjector *businessInjector = [[BusinessInjector alloc] init];
                ForwardSecurityContact *fsContact = [[ForwardSecurityContact alloc] initWithIdentity:[self identity] publicKey:[self publicKey]];
                if ([[businessInjector fsmp] hasContactUsedForwardSecurityWithContact:fsContact]) {
                    [self postPFSNotSupportedSystemMessage];
                }
            }
        }
    }
    
    [self willChangeValueForKey:fieldFeatureLevel];
    [self setPrimitiveValue:featureMask != nil ? featureMask : @0 forKey:fieldFeatureLevel];
    [self didChangeValueForKey:fieldFeatureLevel];
}

- (void)postPFSNotSupportedSystemMessage {
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
            Conversation *conversation = [[entityManager entityFetcher] conversationForContact:self];
        if (conversation != nil) {
            SystemMessage *systemMessage = [entityManager.entityCreator systemMessageForConversation:conversation];
            systemMessage.type = [NSNumber numberWithInt:kSystemMessageFsNotSupportedAnymore];
            systemMessage.remoteSentDate = [NSDate date];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationContactImageChanged object:self];
    [self didChangeValueForKey:@"imageData"];
}

- (void)setContactImage:(ImageData *)contactImage {
    [self willChangeValueForKey:@"contactImage"];
    [self setPrimitiveValue:contactImage forKey:@"contactImage"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationContactImageChanged object:self];
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

- (BOOL)isProfilePictureSet {
    if (self.contactImage != nil && [UserSettings sharedUserSettings].showProfilePictures) {
        return true;
    }
    
    if (self.imageData != nil) {
        return true;
    }
    
    return false;
}

@end
