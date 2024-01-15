//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#import "ErrorNotificationHandler.h"
#import "AppDelegate.h"
#import "AppGroup.h"
#import "BundleUtil.h"
#import "ServerConnector.h"

@implementation ErrorNotificationHandler

static ErrorNotificationHandler *singleton;

+ (void)setup {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[ErrorNotificationHandler alloc] init];
    });
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleServerMessage:) name:kNotificationServerMessage object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnectionFailed:) name:kNotificationErrorConnectionFailed object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUnknownGroup:) name:kNotificationErrorUnknownGroup object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePublicKeyMismatch:) name:kNotificationErrorPublicKeyMismatch object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRogueDevice:) name:kNotificationErrorRogueDevice object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleConnectionFailed:(NSNotification*)notification {
    NSString *title = [notification.userInfo objectForKey:kKeyTitle] ? [notification.userInfo objectForKey:kKeyTitle] : @"Connection error";
    NSString *message = [notification.userInfo objectForKey:kKeyMessage];
    
    [self showAlertWithTitle:title message:message actionOk:nil];
}

- (void)handleUnknownGroup:(NSNotification*)notification {
    NSString *contactDisplayName = [notification.userInfo objectForKey:kKeyContact];
    
    NSString *title = [BundleUtil localizedStringForKey:@"msg_unknown_group_request_sync_x_title"];
    NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"msg_unknown_group_request_sync_x_message"], contactDisplayName];
    
    [self showAlertWithTitle:title message:message actionOk:nil];
}

- (void)handlePublicKeyMismatch:(NSNotification*)notification {
    NSString *title = [BundleUtil localizedStringForKey:@"public_key_mismatch_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"public_key_mismatch_message"];
    
    [self showAlertWithTitle:title message:message actionOk:nil];
}

- (void)handleServerMessage:(NSNotification*)notification {
    NSString *title = [BundleUtil localizedStringForKey:@"server_message_title"];
    NSString *message = [notification.userInfo objectForKey:kKeyMessage];
    
    [self showAlertWithTitle:title message:message actionOk:nil];
}

- (void)handleRogueDevice:(NSNotification*)notification {
    NSString *title = [BundleUtil localizedStringForKey:@"error_rogue_device_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"error_rogue_device_message"];
    
    [self showAlertWithTitle:title message:message actionOk:^(UIAlertAction * action) {
        [[ServerConnector sharedServerConnector] clearDeviceCookieChangedIndicator];
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message actionOk:(void (^)(UIAlertAction*))actionOk {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = [[[AppDelegate sharedAppDelegate] window] rootViewController];
        [UIAlertTemplate showAlertWithOwner:vc title:title message:message actionOk:actionOk];
    });
}
@end
