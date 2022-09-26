//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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
#import "MKNumberBadgeView.h"
#import "Conversation.h"
#import "ImageMessageEntity.h"

@class Old_ChatViewController;
@class HairlineView;

@protocol ChatViewHeaderDelegate <NSObject>

- (void)didChangeHeightTo:(CGFloat)newHeight;

@end

@interface ChatViewHeader : UIView

@property (weak) Old_ChatViewController *chatViewController;
@property (nonatomic) Conversation *conversation;

@property (weak, nonatomic) IBOutlet UIView *wrapperView;

@property (weak, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UIView *optionalButtonsView;

@property (weak, nonatomic) IBOutlet UIButton *callButton;
@property (weak, nonatomic) IBOutlet UIButton *avatarButton;
@property (weak, nonatomic) IBOutlet UIButton *verificationLevel;

@property (weak, nonatomic) IBOutlet UIButton *mediaButton;
@property (weak, nonatomic) IBOutlet UIButton *ballotsButton;
@property (weak, nonatomic) IBOutlet UIButton *searchButton;
@property (weak, nonatomic) IBOutlet UIButton *notificationsSettingsButton;

@property (weak, nonatomic) IBOutlet MKNumberBadgeView *ballotBadge;

@property (weak, nonatomic) IBOutlet HairlineView *verticalDividerLine1;
@property (weak, nonatomic) IBOutlet HairlineView *verticalDividerLine2;
@property (weak, nonatomic) IBOutlet UIView *verticalDividerLine3;
@property (weak, nonatomic) IBOutlet HairlineView *horizontalDividerLine1;
@property (weak, nonatomic) IBOutlet HairlineView *horizontalDividerLine2;
@property (weak, nonatomic) IBOutlet UIImageView *threemaTypeIcon;

@property (weak) id<ChatViewHeaderDelegate> delegate;

- (IBAction)callAction:(id)sender;
- (IBAction)mediaAction:(id)sender;
- (IBAction)ballotAction:(id)sender;
- (IBAction)searchAction:(id)sender;
- (IBAction)notificationsSettingsAction:(id)sender;

- (UIViewController *)getPhotoBrowserAtMessage:(BaseMessage*)msg forPeeking:(BOOL)peeking;

- (void)cleanupMedia;

- (CGFloat)getHeight;

- (void)refresh;

- (void)cancelSearch;

- (NSUInteger)mediaSelectionCount;

- (NSSet *)mediaPhotoSelection;

- (void)showThreemaVideoCallInfo;

@end
