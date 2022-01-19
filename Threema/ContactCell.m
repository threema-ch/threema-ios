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

#import "ContactCell.h"
#import "Contact.h"
#import "ContactNameLabel.h"
#import "BundleUtil.h"
#import "AvatarMaker.h"
#import "UserSettings.h"
#import "BundleUtil.h"
#import "Utils.h"

@implementation ContactCell

- (void)awakeFromNib {
    [super awakeFromNib];
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    if (@available(iOS 11.0, *)) {
        _contactImage.accessibilityIgnoresInvertColors = true;
        _threemaTypeIcon.accessibilityIgnoresInvertColors = true;
    }
}

- (void)setContact:(Contact *)contact {
    _contact = contact;
    
    self.nameLabel.contact = contact;
    
    self.contactImage.image = [BundleUtil imageNamed:@"Unknown"];
    [[AvatarMaker sharedAvatarMaker] avatarForContact:contact size:40.0f masked:YES onCompletion:^(UIImage *avatarImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contactImage.image = avatarImage;
        });
    }];
    
    if (contact.publicNickname && contact.publicNickname.length > 0) {
        NSString *nickname = contact.publicNickname;
        if ([contact.publicNickname isEqualToString:contact.identity] == NO) {
            nickname = [NSString stringWithFormat:@"%@", contact.publicNickname];
        } else {
            nickname = @" ";
        }
        self.nicknameLabel.text = nickname;
    } else {
        self.nicknameLabel.text = @" ";
    }
    
    self.identityLabel.text = contact.identity;
    self.verificationLevel.image = [contact verificationLevelImageSmall];
    
    [self updateState];
    
    self.nameLabel.highlightedTextColor = self.nameLabel.textColor;
    
    _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:self.contact];
}

- (void)updateState {
    CGFloat alpha;
    
    if (_contact.isActive) {
        alpha = 1.0;
    } else {
        alpha = 0.5;
    }
    
    self.contactImage.alpha = alpha;
    self.verificationLevel.alpha = alpha;
    self.nicknameLabel.alpha = alpha;
    self.identityLabel.alpha = alpha;
}

- (NSString *)accessibilityLabel {
    NSMutableString *text = [NSMutableString stringWithString:_nameLabel.accessibilityLabel];
    
    [text appendFormat:@". %@.", _contact.identity];

    [text appendFormat:@". %@", [_contact verificationLevelAccessibilityLabel]];
    
    return text;
}

@end
