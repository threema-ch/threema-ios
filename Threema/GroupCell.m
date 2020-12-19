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

#import "GroupCell.h"
#import "AvatarMaker.h"
#import "BundleUtil.h"

@implementation GroupCell

- (void)awakeFromNib {
    [super awakeFromNib];

    if (@available(iOS 11.0, *)) {
        _groupImage.accessibilityIgnoresInvertColors = true;
    }
}

- (void)setGroup:(GroupProxy *)group {
    _group = group;
    
    _groupImage.image = [BundleUtil imageNamed:@"Unknown"];
    [[AvatarMaker sharedAvatarMaker] avatarForConversation:group.conversation size:40.0f masked:YES onCompletion:^(UIImage *avatarImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _groupImage.image = avatarImage;
        });
    }];
    
    NSString *groupName = group.conversation.displayName;
    
    [_groupNameLabel setText: groupName];
    
    NSString *creator = [_group creatorString];
    NSString *memberCount = [_group membersSummaryString];
    
    [_creatorLabel setText:creator];
    [_countMemberLabel setText:memberCount];
}

@end
