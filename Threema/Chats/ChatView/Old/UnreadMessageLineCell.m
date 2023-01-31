//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2023 Threema GmbH
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

#import "UnreadMessageLineCell.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"

@implementation UnreadMessageLineCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    _unreadMessagesLabel.text = [BundleUtil localizedStringForKey:@"unread_messages"];
    
    [self updateColors];
}

- (void)willDisplay {
    [self updateColors];
}

- (void)updateColors {
    [_unreadMessagesLabel setTextColor:Colors.white];
    _unreadMessagesLabel.shadowColor = nil;
    _unreadMessagesLabel.backgroundColor = Colors.backgroundUnreadMessageLine;
    self.backgroundColor = [UIColor clearColor];

    _arrowDownLeft.image = [UIImage imageNamed:@"ArrowDown" inColor:[UIColor whiteColor]];
    _arrowDownRight.image = [UIImage imageNamed:@"ArrowDown" inColor:[UIColor whiteColor]];
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    return nil;
}

@end
