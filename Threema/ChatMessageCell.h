//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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
#import "ChatViewController.h"
#import "MGSwipeTableCell.h"

@class BaseMessage;

@interface ChatMessageCell : UITableViewCell

@property (nonatomic, strong) BaseMessage* message;

@property (nonatomic) BOOL typing;
@property (nonatomic, weak) ChatViewController *chatVc;
@property (nonatomic, readonly) UIImageView *statusImage;
@property (nonatomic, readonly) UIImageView *msgBackground;
@property (nonatomic, readonly) UITapGestureRecognizer *dtgr;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent;

- (void)setupColors;

- (void)setBubbleContentSize:(CGSize)size;

- (void)setBubbleSize:(CGSize)size;

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth;

- (void)updateStatusImage;

- (CGFloat)contentLeftOffset;

- (void)copyMessage:(UIMenuController *)menuController;

- (void)deleteMessage:(UIMenuController*)menuController;

- (void)shareMessage:(UIMenuController *)menuController;

- (void)forwardMessage:(UIMenuController *)menuController;

- (void)quoteMessage:(UIMenuController *)menuController;
- (NSString*)textForQuote;

+ (CGFloat)maxContentWidthForTableWidth:(CGFloat)tableWidth;

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer;

- (NSString*)accessibilityLabelForContent;
- (BOOL)performPlayActionForAccessibility;
- (BOOL)shouldHideBubbleBackground;

- (void)setBubbleHighlighted:(BOOL)bubbleHighlighted;

- (void)showCallMenu;

+ (UIFont *)textFont;
+ (CGFloat)textFontSize;
+ (UIFont *)quoteFont;
+ (CGFloat)quoteFontSize;
+ (UIFont *)quoteIdentityFont;
+ (CGFloat)quoteIdentityFontSize;
+ (UIFont *)emojiFont;
+ (CGFloat)emojiFontSize;

- (BOOL)highlightOccurencesOf:(NSString *)pattern;

+ (NSAttributedString *)highlightedOccurencesOf:(NSString *)pattern inString:(NSString *)text;

- (UIViewController *)previewViewController;

- (UIViewController *)previewViewControllerFor:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location;

- (void)willDisplay;

- (void)didEndDisplaying;

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0));
- (NSArray *)contextMenuItems API_AVAILABLE(ios(13.0));

@end
