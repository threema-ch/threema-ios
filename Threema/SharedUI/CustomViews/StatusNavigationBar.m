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

#import "StatusNavigationBar.h"
#import <UIKit/UIKit.h>
#import "ServerConnector.h"
#import "VoIPHelper.h"
#import "Threema-Swift.h"

#import <QuartzCore/QuartzCore.h>

@implementation StatusNavigationBar {
    UIImageView *statusView;
    UITapGestureRecognizer *tap;
    UIView *navBarTapView;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:(CGRect)frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navigationBarColorShouldChange:) name:kNotificationNavigationBarColorShouldChange object:nil];

    [self addStatusView];
    [[ServerConnector sharedServerConnector] registerConnectionStateDelegate:self];
    [self updateBarBgColor];

    _ignoreSetItems = NO;
}

- (void)addStatusView {
    statusView = [[UIImageView alloc] init];
    [self updateStatusFrame];

    [self addSubview:statusView];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[ServerConnector sharedServerConnector] unregisterConnectionStateDelegate:self];
}

- (void)updateStatusFrame {
    statusView.frame = CGRectMake(0, self.frame.size.height - 2, self.frame.size.width, 2);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateStatusFrame];

    if ([[VoIPHelper shared] isCallActiveInBackground] || [WCSessionHelper isWCSessionConnected]) {
        if (!tap)
            tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(navigationBarTapped:)];

        [self addGestureRecognizer:tap];
    } else {
        dispatch_async(dispatch_get_main_queue(),^{
            [self removeGestureRecognizer:tap];
        });
    }
}

- (void)updateBarBgColor {
    NSString *barBgColor;

    switch ([ServerConnector sharedServerConnector].connectionState) {
        case ConnectionStateConnected:
            barBgColor = @"orange";
            break;
        case ConnectionStateLoggedIn:
            barBgColor = @"green";
            break;
        case ConnectionStateConnecting:
        case ConnectionStateDisconnecting:
        case ConnectionStateDisconnected:
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
                barBgColor = @"green";
            } else {
                barBgColor = @"red";
            }
            break;

        default:
            break;
    }
    [self showOrHideStatusView];
    UIImage *colorBar = [[UIImage imageNamed:[NSString stringWithFormat:@"StatusBar_%@", barBgColor]] resizableImageWithCapInsets:UIEdgeInsetsZero];
    statusView.image = colorBar;
}

- (void)hideStatusView {
    statusView.hidden = true;
}

- (void)showOrHideStatusView {
    switch ([ServerConnector sharedServerConnector].connectionState) {
        case ConnectionStateConnected:
            statusView.hidden = false;
            break;
        case ConnectionStateLoggedIn:
            statusView.hidden = true;
            break;
        case ConnectionStateConnecting:
        case ConnectionStateDisconnecting:
        case ConnectionStateDisconnected:
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
                statusView.hidden = true;
            } else {
                statusView.hidden = false;
            }
            break;

        default:
            break;
    }
}

- (void)navigationBarColorShouldChange:(NSNotification*)notification {
    if ([[VoIPHelper shared] isCallActiveInBackground] || [WCSessionHelper isWCSessionConnected]) {
        if (!tap)
            tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(navigationBarTapped:)];

        [self addGestureRecognizer:tap];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeGestureRecognizer:tap];
        });
    }
    [Colors updateWithNavigationBar:self];
}

- (void)navigationBarTapped:(UITapGestureRecognizer *)tapRecognizer {
    if ([[VoIPHelper shared] isCallActiveInBackground]) {
        [[VoIPCallStateManager shared] presentCallViewController];
    }
    else if ([WCSessionHelper isWCSessionConnected]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *threemaWebVC = [[AppDelegate getSettingsStoryboard] instantiateViewControllerWithIdentifier:@"ThreemaWeb"];
            
            if(SYSTEM_IS_IPAD){
                MainTabBarController *currentVC = (MainTabBarController *)[AppDelegate getMainTabBarController];
                [currentVC showModal:threemaWebVC];
            } else {
                ModalNavigationController* modalVC = [[ModalNavigationController alloc] init];
                modalVC.showDoneButton = YES;
                [modalVC pushViewController:threemaWebVC animated:true];
                UIViewController *currentVC = [[AppDelegate sharedAppDelegate] currentTopViewController];
                [currentVC showViewController:modalVC sender:nil];
            }
        });
    }
}

#pragma mark - ConnectionStateDelegate

- (void)connectionStateChanged:(ConnectionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateBarBgColor];
    });
}

@end
