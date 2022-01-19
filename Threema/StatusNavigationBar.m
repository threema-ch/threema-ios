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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callInBackground:) name:kNotificationCallInBackground object:nil];
    [self addStatusView];
    [[ServerConnector sharedServerConnector] addObserver:self forKeyPath:@"connectionState" options:0 context:nil];
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
    [[ServerConnector sharedServerConnector] removeObserver:self forKeyPath:@"connectionState"];
}

- (void)updateStatusFrame {
    statusView.frame = CGRectMake(0, self.frame.size.height - 2, self.frame.size.width, 2);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateStatusFrame];
    
    if ([[VoIPHelper shared] isCallActiveInBackground]) {
        if (!tap)
            tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showCallScreen:)];
        
        if (@available(iOS 11.0, *)) {
            [self addGestureRecognizer:tap];
        } else {
            CGRect frame = CGRectMake(0, 0, self.bounds.size.width, 32.0);
            navBarTapView = [[UIView alloc] initWithFrame:frame];
            [self addSubview:navBarTapView];
            navBarTapView.backgroundColor = [UIColor clearColor];
            [navBarTapView setUserInteractionEnabled:YES];
            [navBarTapView addGestureRecognizer:tap];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(),^{
            if (@available(iOS 11.0, *)) {
                [self removeGestureRecognizer:tap];
            } else {
                [navBarTapView removeGestureRecognizer:tap];
                [navBarTapView removeFromSuperview];
            }
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (object == [ServerConnector sharedServerConnector] && [keyPath isEqualToString:@"connectionState"]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateBarBgColor];
        });
    }
}

- (void)callInBackground:(NSNotification*)notification {    
    if ([[VoIPHelper shared] isCallActiveInBackground]) {
        if (!tap)
            tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showCallScreen:)];
        
        if (@available(iOS 11.0, *)) {
            [self addGestureRecognizer:tap];
        } else {
            CGRect frame = CGRectMake(0, 0, self.bounds.size.width, 32.0);
            navBarTapView = [[UIView alloc] initWithFrame:frame];
            [self addSubview:navBarTapView];
            navBarTapView.backgroundColor = [UIColor clearColor];
            [navBarTapView setUserInteractionEnabled:YES];
            [navBarTapView addGestureRecognizer:tap];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (@available(iOS 11.0, *)) {
                [self removeGestureRecognizer:tap];
            } else {
                [navBarTapView removeGestureRecognizer:tap];
                [navBarTapView removeFromSuperview];
            }
        });
    }
    [Colors updateNavigationBar:self];
}

- (void)showCallScreen:(UITapGestureRecognizer *)tapRecognizer {
    if ([[VoIPHelper shared] isCallActiveInBackground]) {
        [[VoIPCallStateManager shared] presentCallViewController];
    }
}

@end
