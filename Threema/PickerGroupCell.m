//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "PickerGroupCell.h"
#import "AvatarMaker.h"
#import "PermissionChecker.h"
#import "BundleUtil.h"

@implementation PickerGroupCell

- (void)awakeFromNib {
    [super awakeFromNib];
    _nameLabel.font = [UIFont boldSystemFontOfSize: _nameLabel.font.pointSize];
}

- (void)setGroup:(GroupProxy *)group {
    _group = group;
    
    NSString *groupName = group.conversation.displayName;
    
    [_nameLabel setText: groupName];

    NSString *creator = [_group creatorString];
    NSString *memberCount = [_group membersSummaryString];
    
    [_creatorNameLabel setText:creator];
    [_countMembersLabel setText:memberCount];

    _avatarImage.image = [BundleUtil imageNamed:@"Unknown"];    
    [[AvatarMaker sharedAvatarMaker] avatarForConversation:group.conversation size:_avatarImage.image.size.width masked:YES onCompletion:^(UIImage *avatarImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.avatarImage.image = avatarImage;
        });
    }];
    
    _nameLabel.highlightedTextColor = _nameLabel.textColor;
    
    [self updateState];
}

- (void)updateState {
    if ([[PermissionChecker permissionChecker] canSendIn:_group.conversation entityManager:nil]) {
        _avatarImage.alpha = 1.0;
        _nameLabel.alpha = 1.0;
        self.userInteractionEnabled = YES;
    } else {
        _avatarImage.alpha = 0.5;
        _nameLabel.alpha = 0.5;
        self.userInteractionEnabled = NO;
    }
}

@end
