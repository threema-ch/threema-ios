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

#import "ContactNameLabel.h"
#import "Contact.h"
#import "UserSettings.h"
#import "BundleUtil.h"

@implementation ContactNameLabel

- (void)setContact:(Contact*)contact {
    
    _contact = contact;
    
    [self updateColor];
    
    if (contact == nil) {
        self.text = [BundleUtil localizedStringForKey:@"me"];
        return;
    }
    
    BOOL nameAvailable = NO;
    NSMutableAttributedString *nameLabelStr = [[NSMutableAttributedString alloc] init];
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline];
    CGFloat size = fontDescriptor.pointSize;
    UIFont *normalFont = [UIFont systemFontOfSize:size];
    
    NSMutableDictionary *boldDict = [NSMutableDictionary dictionaryWithObject:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] forKey:NSFontAttributeName];
    NSMutableDictionary *regularDict = [NSMutableDictionary dictionaryWithObject:normalFont forKey:NSFontAttributeName];
    
    if (contact.state.intValue == kStateInvalid) {
        regularDict[NSStrikethroughStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleThick];
        boldDict[NSStrikethroughStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleThick];
    }
    
    if ([self isBlacklisted]) {
        [nameLabelStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"🚫 " attributes:regularDict]];
    }
    
    NSDictionary *firstNameDict = [UserSettings sharedUserSettings].sortOrderFirstName ? boldDict : regularDict;
    NSDictionary *lastNameDict = ![UserSettings sharedUserSettings].sortOrderFirstName ? boldDict : regularDict;
    
    if ([UserSettings sharedUserSettings].displayOrderFirstName) {
        if (contact.firstName != nil && contact.firstName.length > 0) {
            NSAttributedString *firstNameStr = [[NSAttributedString alloc] initWithString:contact.firstName attributes:firstNameDict];
            [nameLabelStr appendAttributedString:firstNameStr];
            nameAvailable = YES;
        }
        
        if (contact.lastName != nil && contact.lastName.length > 0) {
            NSAttributedString *lastNameStr = [[NSAttributedString alloc] initWithString:contact.lastName attributes:lastNameDict];
            if (contact.firstName != nil) {
                /* space */
                [nameLabelStr appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:firstNameDict]];
            }
            [nameLabelStr appendAttributedString:lastNameStr];
            nameAvailable = YES;
        }
    } else {
        if (contact.lastName != nil && contact.lastName.length > 0) {
            NSAttributedString *lastNameStr = [[NSAttributedString alloc] initWithString:contact.lastName attributes:lastNameDict];
            [nameLabelStr appendAttributedString:lastNameStr];
            nameAvailable = YES;
        }
        
        if (contact.firstName != nil && contact.firstName.length > 0) {
            NSAttributedString *firstNameStr = [[NSAttributedString alloc] initWithString:contact.firstName attributes:firstNameDict];
            if (contact.lastName != nil) {
                /* space */
                [nameLabelStr appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:lastNameDict]];
            }
            [nameLabelStr appendAttributedString:firstNameStr];
            nameAvailable = YES;
        }
    }
    
    if (!nameAvailable) {
        /* no name - use nickname or identity */
        if (contact.publicNickname.length > 0 && [contact.publicNickname isEqualToString:contact.identity] == NO) {
            
            NSString *nickname = [NSString stringWithFormat:@"~%@", contact.publicNickname];
            
            NSAttributedString *nicknameStr = [[NSAttributedString alloc] initWithString:nickname attributes:boldDict];
            
            [nameLabelStr appendAttributedString:nicknameStr];
        } else {
            NSAttributedString *identityStr = [[NSAttributedString alloc] initWithString:contact.identity attributes:boldDict];
            [nameLabelStr appendAttributedString:identityStr];
        }
    }
    
    self.attributedText = nameLabelStr;
}

- (BOOL)isBlacklisted {
    return [[UserSettings sharedUserSettings].blacklist containsObject:_contact.identity];
}

- (void)updateColor {
    if (_contact.isActive) {
        self.textColor = [Colors fontNormal];
    } else {
        self.textColor = [Colors fontVeryLight];
    }
}

- (NSString *)accessibilityLabel {
    NSString *appendix = @"";
    if ([self isBlacklisted]) {
        appendix = [BundleUtil localizedStringForKey:@"blocked"];
    } else if (_contact.isActive == NO) {
        appendix = [BundleUtil localizedStringForKey:@"inactive"];
    }
    
    return [NSString stringWithFormat:@"%@. %@", self.text, appendix];
}

@end
