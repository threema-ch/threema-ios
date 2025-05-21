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

#import "Old_ContactCell.h"
#import "ContactNameLabel.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "ThreemaUtilityObjC.h"

@implementation Old_ContactCell

- (void)awakeFromNib {
    [super awakeFromNib];
    _threemaTypeIcon.image = [ThreemaUtility otherThreemaTypeIcon];
    _threemaTypeIcon.accessibilityIgnoresInvertColors = true;
}

- (void)setContact:(ContactEntity *)contact {

    if (contact.willBeDeleted) {
        return;
    }

    _contact = contact;
    
    self.nameLabel.contact = contact;
    
    self.identityLabel.text = contact.identity;
    Contact * businessContact = [[Contact alloc]initWithContactEntity:contact];
    self.verificationLevel.image = [businessContact verificationLevelImageSmall];
    
    [self updateState];
    
    self.nameLabel.highlightedTextColor = self.nameLabel.textColor;
    
    _threemaTypeIcon.hidden = !contact.showOtherThreemaTypeIcon;
}

- (void)updateState {
    CGFloat alpha;
    
    if (_contact.isActive) {
        alpha = 1.0;
    } else {
        alpha = 0.5;
    }
    
    self.verificationLevel.alpha = alpha;
    self.identityLabel.alpha = alpha;
}

- (NSString *)accessibilityLabel {
    NSMutableString *text = [NSMutableString stringWithString:_nameLabel.accessibilityLabel];
    
    [text appendFormat:@". %@.", _contact.identity];
    
    Contact * businessContact = [[Contact alloc]initWithContactEntity:_contact];
    [text appendFormat:@". %@", [businessContact verificationLevelAccessibilityLabel]];
    
    return text;
}

@end
