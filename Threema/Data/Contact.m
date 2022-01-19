//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "Contact.h"
#import "Conversation.h"
#import "UserSettings.h"
#import "BaseMessage.h"
#import "ContactUtil.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation Contact

@dynamic abRecordId;
@dynamic featureLevel;
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
@dynamic messages;
@dynamic contactImage;
@dynamic profilePictureSended;
@dynamic profilePictureUpload;
@dynamic cnContactId;
@dynamic workContact;
@dynamic hidden;


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

    return displayName;
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

+ (NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"firstName", @"lastName", @"publicNickname", @"identity", nil];
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

- (BOOL)isActive {
    return (self.state.intValue == kStateActive);
}

- (BOOL)isValid {
    return (self.state.intValue != kStateInvalid);
}

- (void)setImageData:(NSData *)imageData {
    [self willChangeValueForKey:@"imageData"];
    [self setPrimitiveValue:imageData forKey:@"imageData"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaContactImageChanged" object:self];
    [self didChangeValueForKey:@"imageData"];
}

- (void)setContactImage:(ImageData *)contactImage {
    [self willChangeValueForKey:@"contactImage"];
    [self setPrimitiveValue:contactImage forKey:@"contactImage"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaContactImageChanged" object:self];
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

- (void)setFeatureMask:(NSNumber *)featureMask {
    if (featureMask != nil) {
        self.featureLevel = featureMask;
    } else {
        self.featureLevel = 0;
    }
}

- (NSNumber *)featureMask {
    return self.featureLevel;
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
