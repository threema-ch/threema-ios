//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2021 Threema GmbH
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

#import "UserReminder.h"
#import "UIDefines.h"
#import "MyIdentityViewController.h"
#import "MyIdentityStore.h"
#import "AppDelegate.h"
#import "AppGroup.h"
#import <UserNotifications/UserNotifications.h>

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define kLinkReminderTime  2*86400
#define kPublicNicknameReminderTime  3*86400
#define kPushReminderTime  900
#define kPushReminderInterval   1*86400

@implementation UserReminder {
}

+ (UserReminder*)sharedUserReminder {
    static UserReminder *instance;
	
	@synchronized (self) {
		if (!instance)
			instance = [[UserReminder alloc] init];
	}
	
	return instance;
}

- (void)checkReminders:(void(^)(BOOL check))onCompletion {
    
    if (![[MyIdentityStore sharedMyIdentityStore] isProvisioned]) {
        DDLogVerbose(@"Not provisioned - no reminders to show");
        onCompletion(false);
    }
    
    /* Push reminder: check that push registration was successful */
    [self checkPushReminder:^(BOOL check) {
        if (check == true) {
            onCompletion(true);
            return;
        }
        
        onCompletion(false);
        return;
    }];
}

- (void)isPushEnabled:(void(^)(BOOL isEnabled))onCompletion {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        //1. Query the authorization status of the UNNotificationSettings object
        switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized:
                onCompletion(true);
                break;
            case UNAuthorizationStatusDenied:
                onCompletion(false);
                break;
            case UNAuthorizationStatusNotDetermined:
                onCompletion(false);
                break;
            default:
                onCompletion(false);
                break;
        }
    }];
}

- (void)checkPushReminder:(void(^)(BOOL check))onCompletion {

    [self isPushEnabled:^(BOOL isEnabled) {
        /* push enabled? */
        if (isEnabled) {
            DDLogVerbose(@"Push notifications are enabled");
            onCompletion(false);
            return;
        }
        
        /* less than 15 minutes after identity creation? Give user a chance to accept pushes first */
        NSDate *targetDate = [[self idCreationDate] dateByAddingTimeInterval:kPushReminderTime];
        if ([targetDate compare:[NSDate date]] == NSOrderedDescending) {
            DDLogVerbose(@"Push reminder: not time to show yet");
            onCompletion(false);
            return;
        }
        
        /* already shown? */
        NSDate *lastShow = [[AppGroup userDefaults] objectForKey:@"PushReminderShowDate"];
        BOOL doNotShowAgain = [[AppGroup userDefaults] boolForKey:@"PushReminderDoNotShowAgain"];
        if ((lastShow != nil && -[lastShow timeIntervalSinceNow] < kPushReminderInterval) || doNotShowAgain == true) {
            DDLogVerbose(@"Push reminder already shown");
            onCompletion(false);
            return;
        }
        
        /* time to show the reminder */
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"push_reminder_title", nil) message:NSLocalizedString(@"push_reminder_message", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"safe_intro_cancel", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [[AppGroup userDefaults] setBool:true forKey:@"PushReminderDoNotShowAgain"];
        }]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:alert animated:YES completion:nil];
        });
        
        [[AppGroup userDefaults] setObject:[NSDate date] forKey:@"PushReminderShowDate"];
        
        onCompletion(true);
        return;
    }];
}

- (void)markIdentityDeleted {
    
    [[AppGroup userDefaults] removeObjectForKey:@"LinkReminderShown"];
    [[AppGroup userDefaults] removeObjectForKey:@"PublicNicknameReminderShown"];
    [[AppGroup userDefaults] removeObjectForKey:@"IdentityCreationDate"];
    [[AppGroup userDefaults] removeObjectForKey:@"PushReminderDoNotShowAgain"];
}

- (NSDate*)idCreationDate {
    NSDate *idCreateDate = [[AppGroup userDefaults] objectForKey:@"IdentityCreationDate"];
    if (idCreateDate == nil) {
        /* not available - put in current date */
        DDLogVerbose(@"Init with current date");
        idCreateDate = [NSDate date];
        [[AppGroup userDefaults] setObject:idCreateDate forKey:@"IdentityCreationDate"];
    }
    return idCreateDate;
}

@end
