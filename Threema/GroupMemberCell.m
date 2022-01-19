//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
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

#import "GroupMemberCell.h"
#import "Contact.h"
#import <QuartzCore/QuartzCore.h>
#import "AvatarMaker.h"
#import "MyIdentityStore.h"
#import "Utils.h"
#import "BundleUtil.h"

@implementation GroupMemberCell

@synthesize contact;

- (void)awakeFromNib {
    [super awakeFromNib];
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    if (@available(iOS 11.0, *)) {
        _threemaTypeIcon.accessibilityIgnoresInvertColors = true;
        _contactImage.accessibilityIgnoresInvertColors = true;
    }
}

- (void)setContact:(Contact *)newContact {
    contact = newContact;
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
    CGFloat size = fontDescriptor.pointSize;
    _nameLabel.font = [UIFont boldSystemFontOfSize:size];
    
    self.nameLabel.contact = contact;
    
    self.contactImage.layer.masksToBounds = YES;
    self.contactImage.layer.cornerRadius = 6.0f;
    
    if (_isSelfMember) {
        NSMutableDictionary *profilePicture = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
        UIImage *image = [UIImage imageWithData:profilePicture[@"ProfilePicture"]];
        self.contactImage.image = [[AvatarMaker sharedAvatarMaker] maskedProfilePicture:image size:self.contactImage.frame.size.width];
    } else {
        self.contactImage.image = [BundleUtil imageNamed:@"Unknown"];
        [[AvatarMaker sharedAvatarMaker] avatarForContact:contact size:self.contactImage.frame.size.width masked:YES onCompletion:^(UIImage *avatarImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.contactImage.image = avatarImage;
            });
        }];
    }
    
    self.contactImage.alpha = (contact.state.intValue == kStateInactive) ? 0.5 : 1.0;
    
    [self updateThreemaTypeIcon];
}

- (void)updateThreemaTypeIcon {
    if (_isSelfMember) {
        _threemaTypeIcon.hidden = YES;
    } else {
        _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:contact];
    }
}

@end
