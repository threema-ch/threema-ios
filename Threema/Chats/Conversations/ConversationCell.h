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

#import <UIKit/UIKit.h>
#import "MGSwipeTableCell.h"
#import "TTTAttributedLabel.h"
#import "MKNumberBadgeView.h"

@class Conversation;
@class ConversationCell;

@interface ConversationCell: UITableViewCell

@property (strong, nonatomic) Conversation* conversation;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet TTTAttributedLabel *messagePreviewLabel;
@property (weak, nonatomic) IBOutlet UIImageView *contactImage;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet MKNumberBadgeView *badgeView;
@property (weak, nonatomic) IBOutlet UIImageView *typingIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *statusIcon;
@property (weak, nonatomic) IBOutlet UILabel *draftLabel;
@property (weak, nonatomic) IBOutlet UIImageView *threemaTypeIcon;
@property (weak, nonatomic) IBOutlet UIImageView *callImageView;
@property (weak, nonatomic) IBOutlet UIView *markedView;
@property (weak, nonatomic) IBOutlet UIImageView *notificationIcon;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *callImageHeight;

- (void)addObservers;
- (void)removeObservers;
- (void)changedValuesForConversation:(NSDictionary *)changedValuesForCurrentEvent;
- (void)updateLastMessagePreview;

@end
