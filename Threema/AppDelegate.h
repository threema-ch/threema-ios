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
#import <CoreData/CoreData.h>
#import "KKPasscodeLock.h"
#import "JKLLockScreenViewController.h"
#import <UserNotifications/UserNotifications.h>  

#define BACKGROUND_GRACE_TIME 5.0 // maximum amount of time to stay connected after moving to background (if not connected to Threema Web)
#define BACKGROUND_GRACE_TIME_WEB   30.0 // maximum amount of time to stay connected after moving to background (if connected to Threema Web)
#define PASTEBOARD_IMAGE_UTI    @"ch.threema.app.imgenc"

@protocol MagicTapHandler
- (BOOL)handleMagicTap;
@end

@class AbstractMessage, BaseMessage;

@interface AppDelegate : UIResponder <UIApplicationDelegate, JKLLockScreenViewControllerDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic) CFTimeInterval lastForegroundTransition;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL firstPushHandled;

@property (nonatomic, strong) NSString *urlRestoreData;

@property (nonatomic, strong) NSDate *appLaunchDate;

@property (nonatomic) BOOL isAppLocked;

@property (nonatomic) BOOL isLockscreenDismissed;

@property (weak, nonatomic) id<MagicTapHandler> magicTapHandler;

+ (AppDelegate*)sharedAppDelegate;

- (BOOL)isAppInBackground;

+ (UIAlertController *)isAlertViewShown;
- (BOOL)isPresentingKeyGeneration;
- (BOOL)isPresentingEnterLicense;
- (void)presentKeyGeneration;
- (void)presentIDBackupRestore;
- (void)completedIDSetup;
- (void)presentPasscodeView;
- (UIViewController *)currentTopViewController;
+ (BOOL)hasBottomSafeAreaInsets;

+ (void)setupConnection;
- (void)handleRemoteNotification:(NSDictionary*)userInfo receivedWhileRunning:(BOOL)receivedWhileRunning notification:(UNNotification *)notification;

+ (UIStoryboard *)getLaunchStoryboard;
+ (UIStoryboard *)getMainStoryboard;
+ (UIStoryboard *)getSettingsStoryboard;
+ (UIStoryboard *)getMyIdentityStoryboard;
+ (UITabBarController *)getMainTabBarController;

@end
