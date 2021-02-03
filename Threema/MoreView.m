//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "MoreView.h"
#import "BundleUtil.h"
#import "UIDefines.h"
#import "RectUtil.h"
#import "UIImage+ColoredImage.h"

#define X_OFFSET 36.0
#define Y_OFFSET_MESSAGE 28.0
#define HEIGHT_TITLE 22.0
#define HEIGHT_MESSAGE 320.0
#define X_PADDING 10.0

#define FONT_SMALL [UIFont systemFontOfSize:14]
#define FONT_TALL [UIFont systemFontOfSize:16]

@interface MoreView ()

@property CGRect originalRect;
@property BOOL isShown;

@property UIImageView *iconView;
@property UILabel *moreLabel;
@property UITextView *messageLabel;

@end

@implementation MoreView

@synthesize moreButtonTitle = _moreButtonTitle;

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
#if !TARGET_INTERFACE_BUILDER
    UIImage *iconImage = [BundleUtil imageNamed:@"InfoFilled"];
    _iconView = [[UIImageView alloc] initWithImage:iconImage];
    _iconView.frame = CGRectMake(4.0, 2.0, 22.0, 22.0);
    [self addSubview:_iconView];
#endif
    
    CGFloat labelWidth = self.frame.size.width - X_OFFSET;
    CGRect rect = CGRectMake(X_OFFSET, 2.0, labelWidth, HEIGHT_TITLE);
    _moreLabel = [[UILabel alloc] initWithFrame:rect];
    _moreLabel.font = FONT_SMALL;
    _moreLabel.textColor = [Colors mainThemeDark];
    _moreLabel.lineBreakMode = NSLineBreakByClipping;
    _moreLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _moreLabel.text = [BundleUtil localizedStringForKey:@"more_information"];
    _moreLabel.backgroundColor = [UIColor clearColor];
    _moreLabel.accessibilityTraits = UIAccessibilityTraitButton;
    
    [self addSubview:_moreLabel];

    CGRect rectMessage = CGRectMake(X_OFFSET - 4.0, Y_OFFSET_MESSAGE, labelWidth, HEIGHT_MESSAGE);
    _messageLabel = [[UITextView alloc] initWithFrame:rectMessage];
    _messageLabel.font = FONT_TALL;
    _messageLabel.textColor = [UIColor whiteColor];
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageLabel.hidden = YES;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.editable = NO;
    
    [self addSubview:_messageLabel];

    CGFloat y = CGRectGetMaxY(rectMessage) + 8.0;
    CGRect buttonRect = CGRectMake(0.0, y, 120.0, 36.0);
    _okButton = [[UIButton alloc] initWithFrame:buttonRect];
    _okButton.layer.cornerRadius = 3;
    _okButton.backgroundColor = [Colors mainThemeDark];
    _okButton.titleLabel.font = FONT_SMALL;
    [_okButton setTitleColor:[Colors white] forState:UIControlStateNormal];

    [_okButton setTitle:[BundleUtil localizedStringForKey:@"ok"] forState:UIControlStateNormal];
    _okButton.hidden = YES;
    [self addSubview:_okButton];
    
    _centerMoreView = NO;
}

- (void)setMoreButtonTitle:(NSString *)moreButtonTitle {
    _moreButtonTitle = moreButtonTitle;
    _moreLabel.text = _moreButtonTitle;
}

- (void)showMoreView {
    self.userInteractionEnabled = NO;
    _messageLabel.text = _moreMessageText;
    _originalRect = self.frame;
    _messageLabel.hidden = NO;
    _messageLabel.alpha = 0.0;
    
    CGRect buttonRect = [RectUtil rect:_okButton.frame centerHorizontalIn:self.frame round:YES];
    _okButton.frame = buttonRect;
    
    CGRect rect = [RectUtil offsetAndResizeRect:self.frame byX:0 byY:-(CGRectGetMinY(_okButton.frame))];
    CGFloat width = CGRectGetMaxX(_mainView.frame) - rect.origin.x - 2 * X_PADDING;
    rect = [RectUtil setWidthOf:rect width:width];
    if (_centerMoreView) {
        rect = CGRectMake((self.window.frame.size.width - rect.size.width)/2, (_mainView.frame.size.height - rect.size.height)/2, rect.size.width, rect.size.height);
        _okButton.frame = CGRectMake((rect.size.width - buttonRect.size.width)/2, buttonRect.origin.y, buttonRect.size.width, buttonRect.size.height);
    } else {
        _okButton.frame = CGRectMake(((rect.size.width - buttonRect.size.width) / 2) + X_PADDING, buttonRect.origin.y, buttonRect.size.width, buttonRect.size.height);
    }
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        self.frame = rect;
        _mainView.alpha = 0.0;
        _messageLabel.alpha = 1.0;
        _moreLabel.font = FONT_TALL;
        [_messageLabel setContentOffset:CGPointZero animated:NO];
    } completion:^(BOOL finished) {
        _okButton.hidden = NO;
        _mainView.hidden = YES;
        _isShown = YES;

        self.userInteractionEnabled = YES;
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.moreMessageText);
    }];
}

- (void)hideMoreView {
    self.userInteractionEnabled = NO;
    _mainView.alpha = 0.0;
    _mainView.hidden = NO;
    _okButton.hidden = YES;

    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        self.frame = _originalRect;
        _mainView.alpha = 1.0;
        _messageLabel.alpha = 0.0;
        _moreLabel.font = FONT_SMALL;
    } completion:^(BOOL finished) {
        _messageLabel.hidden = YES;
        _mainView.hidden = NO;
        _isShown = NO;
        self.userInteractionEnabled = YES;
    }];
}

- (void)toggle {
    if (_isShown) {
        [self hideMoreView];
    } else {
        [self showMoreView];
    }
}

@end
