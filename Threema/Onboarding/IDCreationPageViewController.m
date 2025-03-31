//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import "IDCreationPageViewController.h"
#import "RectUtil.h"
#import "AppDelegate.h"

@interface IDCreationPageViewController ()

@property UIView *infoIconView;

@end

@implementation IDCreationPageViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (SYSTEM_IS_IPAD) {
        CGRect mainRect = _mainContentView.frame;
        
        if ([AppDelegate hasBottomSafeAreaInsets]) {
            mainRect.size.height -= 20.0;
        }
        
        // stick to lower left corner of main view
        CGRect rect = [RectUtil setPositionOf:_moreView.frame x:CGRectGetMinX(mainRect) y:CGRectGetMaxY(mainRect)];
        _moreView.frame = rect;
    } else {
        if ([self shouldAdaptToSmallScreen]) {
            // e.g. iPhone 4 etc
            [self adaptToSmallScreen];
        }
        
        if ([AppDelegate hasBottomSafeAreaInsets]) {
            _moreView.frame = CGRectMake(_moreView.frame.origin.x, _moreView.frame.origin.y - 20.0, _moreView.frame.size.width, _moreView.frame.size.height);
        }
    }
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMoreMessage:)];
    [_moreView addGestureRecognizer:tapGesture];
    _moreView.userInteractionEnabled = YES;
    [_moreView.okButton addTarget:self action:@selector(tappedMoreMessage:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    if (SYSTEM_IS_IPAD) {
        CGRect mainRect = _mainContentView.frame;
        
        if ([AppDelegate hasBottomSafeAreaInsets]) {
            mainRect.size.height -= 20.0;
        }
        
        // stick to lower left corner of main view
        CGRect rect = [RectUtil setPositionOf:_moreView.frame x:CGRectGetMinX(mainRect) y:CGRectGetMaxY(mainRect)];
        _moreView.frame = rect;
    } else {
        if ([self shouldAdaptToSmallScreen]) {
            // e.g. iPhone 4 etc
            [self adaptToSmallScreen];
        }
        
        if ([AppDelegate hasBottomSafeAreaInsets]) {
            _moreView.frame = CGRectMake(_moreView.frame.origin.x, _moreView.frame.origin.y - 20.0, _moreView.frame.size.width, _moreView.frame.size.height);
        }
    }
}

- (void)adaptToSmallScreen {
    CGRect rect = [RectUtil offsetRect:self.view.frame byX:0.0 byY:-28.0];
    self.view.frame = rect;
}

- (BOOL)shouldAdaptToSmallScreen {
    return self.view.frame.size.height < 580.0;
}

- (void)showMessageView:(UIView *)messageView {
    messageView.alpha = 0.0;
    messageView.hidden = NO;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        _mainContentView.alpha = 0.0;
        messageView.alpha = 1.0;
        _moreView.alpha = 0.0;
        
        [self.containerDelegate hideControls:YES];
    } completion:^(BOOL finished) {
        _mainContentView.hidden = YES;
        messageView.hidden = NO;
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, messageView);
    }];
}

- (void)hideMessageView:(UIView *)messageView {
    [self hideMessageView:messageView ignoreControls:NO];
}

- (void)hideMessageView:(UIView *)messageView ignoreControls:(BOOL)ignoreControls {
    _mainContentView.alpha = 0.0;
    _mainContentView.hidden = NO;
    
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.3 delay:0.0 options:options animations:^{
        messageView.alpha = 0.0;
        _mainContentView.alpha = 1.0;
        _moreView.alpha = 1.0;
        if (ignoreControls == NO) {
            [self.containerDelegate hideControls:NO];
        }
    } completion:^(BOOL finished) {
        messageView.hidden = YES;
        _mainContentView.hidden = NO;
        
    }];
}

#pragma mark - UITapGestureRecognizer

- (void)tappedMoreMessage:(UITapGestureRecognizer *)sender
{
    [self.containerDelegate hideControls: (_moreView.isShown == NO)];

    if (sender.state == UIGestureRecognizerStateEnded || [sender isKindOfClass:[UIButton class]]) {
        [_moreView toggle];
    }
}


@end
