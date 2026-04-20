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

@class AbstractMessage, BaseMessageEntity, LaunchTaskManager;

@interface AppDelegate : UIResponder <UIApplicationDelegate, JKLLockScreenViewControllerDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;
/// Note: This should be used only internally, we must expose it since we use it in extensions.
@property (nonatomic) LaunchTaskManager *launchTaskManager;

@property (atomic) BOOL isBusinessInjectorReady;

@property (nonatomic) CFTimeInterval lastForegroundTransition;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL firstPushHandled;

@property (nonatomic, strong) NSString *urlRestoreData;

@property (nonatomic, strong) NSDate *appLaunchDate;

@property (nonatomic) BOOL isAppLocked;
@property (nonatomic) NSURL *pendingUrl;
@property (nonatomic) UIApplicationShortcutItem *pendingShortCutItem;

@property (nonatomic) UIInterfaceOrientationMask orientationLock;

@property (nonatomic, readonly) BOOL isWorkContactsLoading;

@property (weak, nonatomic) id<MagicTapHandler> magicTapHandler;

/// `AppCoordinator` type is not possible to be used here, as the bridge depends
/// on `AppDelegate.h`, creating a circular dependency.
@property (nonatomic, strong, readonly) id appCoordinator;

+ (AppDelegate*)sharedAppDelegate;
+ (UIAlertController *)isAlertViewShown;
+ (BOOL)hasBottomSafeAreaInsets;
+ (void)setupConnection;

- (UITabBarController *)tabBarController;
- (BOOL)isAppInBackground;
- (BOOL)isPresentingKeyGeneration;
- (BOOL)isPresentingEnterLicense;
- (void)presentKeyGeneration;
- (void)presentIDBackupRestore;
- (void)completedIDSetup;
- (void)presentPasscodeView;
- (UIViewController *)currentTopViewController;
- (void)eraseApplicationData;
- (void)handlePresentingScreensWithForce:(BOOL)Force;
- (void)setIsWorkContactsLoading:(BOOL)loading;

@end
