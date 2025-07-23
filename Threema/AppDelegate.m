//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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

#import <CommonCrypto/CommonCrypto.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "AppDelegate.h"
#import "NaClCrypto.h"
#import "ServerConnector.h"
#import "MyIdentityStore.h"
#import "ContactStore.h"
#import "UIDefines.h"
#import "ServerAPIConnector.h"
#import "UserSettings.h"
#import "TypingIndicatorManager.h"
#import "MyIdentityStore.h"
#import "PortraitNavigationController.h"
#import "ThreemaUtilityObjC.h"
#import "ContactsViewController.h"
#import "ProtocolDefines.h"
#import "PhoneNumberNormalizer.h"
#import "AbstractGroupMessage.h"
#import "NSString+Hex.h"
#import "NewMessageToaster.h"
#import "EntityFetcher.h"
#import "SplitViewController.h"
#import "GatewayAvatarMaker.h"
#import "ErrorHandler.h"
#import "DatabaseManager.h"
#import "TouchIdAuthentication.h"
#import "ErrorNotificationHandler.h"
#import "SplashViewController.h"

#import "ActivityIndicatorProxy.h"
#import "BundleUtil.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "EnterLicenseViewController.h"
#import "WorkDataFetcher.h"
#import "IdentityBackupStore.h"

#import "URLHandler.h"
#import "MDMSetup.h"
#import "NSString+Hex.h"

#import "BoxBallotCreateMessage.h"
#import "BallotMessageDecoder.h"
#import "BoxImageMessage.h"
#import "GroupImageMessage.h"
#import "BoxVideoMessage.h"
#import "GroupVideoMessage.h"
#import "PushPayloadDecryptor.h"
#import "Threema-Swift.h"
#import "ThreemaFramework.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"
#import "MainTabBarController.h"
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>
#import <Intents/Intents.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <MBProgressHUD/MBProgressHUD.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@interface AppDelegate () <EnterLicenseDelegate, PKPushRegistryDelegate>

@end

@implementation AppDelegate  {
    NSDictionary *launchOptions;
    StoreRequiresMigration requiresMigration;
    BOOL migrating;
    BOOL databaseImported;
    NSURL *pendingUrl;
    BOOL protectedDataWillBecomeUnavailable;
    NewMessageToaster *toaster;
    UIViewController *lastViewController;
    UIApplicationShortcutItem *pendingShortCutItem;
    BOOL shouldLoadUIForEnterForeground;
    BOOL isEnteringForeground;
    BOOL startCheckBiometrics;
    BOOL rootToNotificationSettings;
    UIView *lockView;
    IncomingMessageManager *incomingMessageManager;
    NotificationManager *notificationManager;
    DeviceLinking *deviceLinking;
    NSData *evaluatedPolicyDomainState;
    GroupCallUIHelper *groupCallUIHelper;
    AppCoordinator *appCoordinator;
}

@synthesize window = _window;
@synthesize urlRestoreData;
@synthesize appLaunchDate;
@synthesize isAppLocked;
@synthesize isLockscreenDismissed;
@synthesize orientationLock;
@synthesize isWorkContactsLoading;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [AppGroup setGroupId:[BundleUtil threemaAppGroupIdentifier]];
        [AppGroup setAppId:[[BundleUtil mainBundle] bundleIdentifier]];
        
#ifdef DEBUG
        [LogManager initializeGlobalLoggerWithDebug:YES];
#else
        [LogManager initializeGlobalLoggerWithDebug:NO];
#endif

        // Checking database file exists as early as possible
        [AppSetup registerIfADatabaseFileExists];
    });
}

+ (AppDelegate*)sharedAppDelegate {
    __block AppDelegate *appDelegate = nil;
    if ([NSThread isMainThread]) {
        appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        });
    }
    
    return appDelegate;
}

#pragma mark - Launching

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)_launchOptions
{
    // If we are in Preview mode for Swift-UI, we directly return to not make previews crash after a second
    if ([[[NSProcessInfo processInfo] environment][@"XCODE_RUNNING_FOR_PREVIEWS"] isEqualToString: @"1"]) {
        return YES;
    }
    
    // Initializing this will also register all tasks, see documentation for more info.
    [ThreemaBGTaskManager shared];
    
    [self registerLifetimeObservers];
    [PromiseKitConfiguration configurePromiseKit];
    
    shouldLoadUIForEnterForeground = false;
    isEnteringForeground = false;
    databaseImported = false;
    startCheckBiometrics = false;
    launchOptions = _launchOptions;
    isLockscreenDismissed = true;
    isWorkContactsLoading = false;
    orientationLock = UIInterfaceOrientationMaskAll;

    [ErrorNotificationHandler setup];

    appLaunchDate = [NSDate date];
    
    DDLogNotice(@"AppState: didFinishLaunchingWithOptions");
    DDLogNotice(@"Current App Version: %@", [ThreemaUtility clientVersionWithMDM]);
    
    /* Instantiate various singletons now */
    [NaClCrypto sharedCrypto];
    [[ServerConnector sharedServerConnector] setIsAppInBackground:[self isAppInBackground]];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    if (ProcessInfoHelper.isRunningForScreenshots) {
        [[UserSettings sharedUserSettings] setIncludeCallsInRecents:false];
        [UIView setAnimationsEnabled:false];
    }
    
    [Colors initTheme];
    [Colors updateWithWindow:_window];
    pendingShortCutItem = [launchOptions objectForKey:UIApplicationLaunchOptionsShortcutItemKey];
    
    [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionProvidesAppNotificationSettings) completionHandler:^(__unused BOOL granted, __unused NSError * _Nullable error) {
    }];

    PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    pushRegistry.delegate = self;
    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLicenseMissing:) name:kNotificationLicenseMissing object:nil];
        
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            //
        }];
    }

#ifdef DEBUG
    if ([[DatabaseManager dbManager] copyOldVersionOfDatabase]) {
        DDLogWarn(@"Old version of database would be applied. Start the app again for testing database migration! Caution, please check on devices that the App is not running (in background) anymore, otherwise migration will fail!!!");
        exit(EXIT_SUCCESS);
    }
#endif

    // if database must migrate and app runs in background (e.g of push request), show local notification to start app in foreground
    DatabaseManager *dbManager = [DatabaseManager dbManager];
    requiresMigration = [dbManager storeRequiresMigration];
    if (([dbManager storeRequiresImport] || requiresMigration == RequiresMigration || [AppMigration isMigrationRequiredWithUserSettings:[UserSettings sharedUserSettings]]) && [self isAppInBackground]) {
        [NotificationManager showNoAccessToDatabaseNotificationWithCompletionHandler:^{
            sleep(2);
            exit(EXIT_SUCCESS);
        }];
        return NO;
    }

    if ([dbManager storeRequiresImport]) {
        DDLogVerbose(@"Store will be import and start migration");
        migrating = YES;
        
        [self performSelectorOnMainThread:@selector(launchImportDatabase) withObject:nil waitUntilDone:NO];
    } else {
        if (requiresMigration == RequiresMigrationError) {
            /* Is protected data is not available, then we show a other notification */
            if ([[MyIdentityStore sharedMyIdentityStore] isKeychainLocked]) {
                [NotificationManager showNoAccessToDatabaseNotificationWithCompletionHandler:^{
                    exit(EXIT_SUCCESS);
                }];
            } else {
                [ThreemaUtilityObjC sendErrorLocalNotification:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_title"] body:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_description"] userInfo:@{@"threema": @{@"cmd": @"error", @"error": @"migration"}} onCompletion:^{
                    // Wait 2 seconds to be sure the notification is fired
                    [ThreemaUtilityObjC waitForSeconds:2 finish:^{
                        exit(EXIT_SUCCESS);
                    }];
                }];
            }
        }
        else if (requiresMigration == RequiresMigration || ([AppMigration isMigrationRequiredWithUserSettings:[UserSettings sharedUserSettings]] && [AppSetup hasPreexistingDatabaseFile])) {
            DDLogVerbose(@"Store requires migration");
            migrating = YES;
            
            /* run phase 2 (which involves migration) separately to avoid getting killed with "failed to launch in time" */
            [self performSelectorOnMainThread:@selector(launchPhase2) withObject:nil waitUntilDone:NO];
        }
        else {
            /* run phase 3 immediately */
            [self launchPhase3];
        }
    }
    
    // Delete Threema-ID-Backup when backup is blocked from MDM
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if (mdmSetup.disableBackups || mdmSetup.disableIdExport || mdmSetup.disableSystemBackups) {
        [IdentityBackupStore deleteIdentityBackup];
    }
    
    // Prevent or release iOS iCloud backup
    [dbManager disableBackupForDatabaseDirectory:(mdmSetup.disableBackups || mdmSetup.disableSystemBackups)];

    [self registerMemoryWarningNotifications];
    
    return YES;
}

- (void)launchImportDatabase {
    UIImage *copyDatabaseBg;
    if ([UIScreen mainScreen].bounds.size.height > 480.0f)
        copyDatabaseBg = [UIImage imageNamed:@"migration_bg_2.jpg"];
    else
        copyDatabaseBg = [UIImage imageNamed:@"migration_bg_1.jpg"];
    UIImageView *copyDatabaseBgView = [[UIImageView alloc] initWithImage:copyDatabaseBg];
    copyDatabaseBgView.frame = self.window.frame;
    copyDatabaseBgView.contentMode = UIViewContentModeScaleAspectFill;
    [self.window addSubview:copyDatabaseBgView];
    [self.window makeKeyAndVisible];

    /* display spinner during copy database */
    
    MBProgressHUD *progressHUD = [[MBProgressHUD alloc] initWithView:self.window];
    progressHUD.label.numberOfLines = 0;
    progressHUD.label.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"updating_database"], TargetManagerObjc.appName];
    progressHUD.mode = MBProgressHUDModeIndeterminate;

    [self.window addSubview:progressHUD];
    [progressHUD showAnimated:YES];
    
    /* run copy database now in background */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].idleTimerDisabled = YES;
        });
        DatabaseManager *dbManager = [DatabaseManager dbManager];
        [dbManager copyImportedDatabase];
        
        NSError *storeError = [dbManager storeError];
        if (storeError != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressHUD hideAnimated:YES];
                [progressHUD removeFromSuperview];
                [ErrorHandler abortWithError: storeError additionalText:@"Failed to import database"];
                /* do not run launchPhase3 at this point, as we shouldn't load the main storyboard and cause any database accesses */
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (requiresMigration == RequiresMigrationError) {
                    [ThreemaUtilityObjC sendErrorLocalNotification:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_title"] body:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_description"] userInfo:nil];
                }
                else if (requiresMigration == RequiresMigration || [AppMigration isMigrationRequiredWithUserSettings:[UserSettings sharedUserSettings]]) {
                    DDLogVerbose(@"Store requires migration");
                    databaseImported = YES;
                    /* run phase 2 (which involves migration) separately to avoid getting killed with "failed to launch in time" */
                    [self performSelectorOnMainThread:@selector(launchPhase2) withObject:nil waitUntilDone:NO];
                } else {
                    [progressHUD hideAnimated:YES];
                    [progressHUD removeFromSuperview];
                    migrating = NO;
                    /* run phase 3 immediately */
                    [self applicationDidBecomeActive:[UIApplication sharedApplication]];
                    [UIApplication sharedApplication].idleTimerDisabled = NO;
                    [self launchPhase3];
                }
            });
        }
    });
}

- (void)launchPhase2 {
    /* migration phase */
    NSURL *logFile = [LogManager dbMigrationLogFile];
    [LogManager deleteLogFile:logFile];
    [LogManager addFileLogger:logFile];

    if (databaseImported == false) {
        UIView *migrationBgView = [[UIView alloc] initWithFrame:self.window.frame];
        migrationBgView.contentMode = UIViewContentModeScaleAspectFill;
        migrationBgView.backgroundColor = UIColor.blackColor;
        [self.window addSubview:migrationBgView];
        [self.window makeKeyAndVisible];
    }

    /* check disk space first */
    if ([[DatabaseManager dbManager] canMigrateDB] == NO) {
        return;
    }
    
    MBProgressHUD *progressHUD = [[MBProgressHUD alloc] initWithView:self.window];
    progressHUD.label.numberOfLines = 0;

    if (databaseImported == false) {
        /* display spinner during migration */
        progressHUD.label.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"updating_database"], TargetManagerObjc.appName];
        progressHUD.mode = MBProgressHUDModeIndeterminate;

        [self.window addSubview:progressHUD];
        [progressHUD showAnimated:YES];
    }
    
    /* run migration now in background */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].idleTimerDisabled = YES;
        });
        
        NSError *storeError = nil;
        if (requiresMigration == RequiresMigration) {
            DatabaseManager *dbManager = [DatabaseManager dbManager];
            [dbManager doMigrateDB];
            storeError = [dbManager storeError];
        }

        if (storeError != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressHUD hideAnimated:YES];
                [progressHUD removeFromSuperview];
                [ErrorHandler abortWithError: storeError additionalText:[BundleUtil localizedStringForKey:@"database_migration_error_hints"]];
                /* do not run launchPhase3 at this point, as we shouldn't load the main storyboard and cause any database accesses */
            });
        } else {
            if ([AppMigration isMigrationRequiredWithUserSettings:[UserSettings sharedUserSettings]]) {
                NSError *error;
                // AppMigration makes sure to only throw erros that are considered fatal i.e. the migration failed and we expect
                // the app to not be usable without it.
                [[AppMigration new] runAndReturnError:&error];

                if (error != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [ErrorHandler abortWithError: error additionalText:[BundleUtil localizedStringForKey:@"database_migration_error_hints"]];
                    });
                    return;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressHUD hideAnimated:YES];
                [progressHUD removeFromSuperview];
                [self launchPhase3];
                migrating = NO;
                [self applicationDidBecomeActive:[UIApplication sharedApplication]];
                [UIApplication sharedApplication].idleTimerDisabled = NO;
            });
        }
    });
}

- (void)launchPhase3 {
    /* Check that the store is OK */
    NSError *storeError = [[DatabaseManager dbManager] storeError];
    if (storeError != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ErrorHandler abortWithError: storeError];
            return;
        });
    }

    NSURL *logFile = [LogManager dbMigrationLogFile];
    [LogManager removeFileLogger:logFile];

    notificationManager = [[NotificationManager alloc] init];
    
    incomingMessageManager = [IncomingMessageManager new];
    
    // Register message processor delegate
    [[ServerConnector sharedServerConnector] registerMessageProcessorDelegate:incomingMessageManager];

    [AppDelegate sharedAppDelegate];
    
    [[KKPasscodeLock sharedLock] setDefaultSettings];
    [[KKPasscodeLock sharedLock] upgradeAccessibility];
    [KKPasscodeLock sharedLock].attemptsAllowed = 10;

    /* generate key pair and register with server if not existing */
    if (![AppSetup isCompleted]) {
        if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
            [self presentPasscodeView];
        }
        else {
            [self presentKeyGenerationOrProtectedDataUnavailable];
        }
        [self.window makeKeyAndVisible];
        return;
    }
    
    AppLaunchTasks *appLaunchTasks = [AppLaunchTasks new];
    [appLaunchTasks runLaunchEventDidFinishLaunching];
    
    [incomingMessageManager showIsNotPending];

    // apply MDM parameter anyway, perhaps company MDM has changed
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadRenewableValues];

    [TypingIndicatorManager sharedInstance];
    
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    
    if ((state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer) | ![[KKPasscodeLock sharedLock] isPasscodeRequired]) {
         [self presentApplicationUI];
     } else {
         [self presentPasscodeView];
     }
    
#if DEBUG
    GroupManager *groupManager = [[BusinessInjector new] groupManagerObjC];
    [groupManager deleteAllSyncRequestRecords];
#endif

    [self.window makeKeyAndVisible];
    
    toaster = [[NewMessageToaster alloc] init];
    
    groupCallUIHelper = [GroupCallUIHelper new];
    [groupCallUIHelper setGlobalGroupCallsManagerSingletonUIDelegate];

    [self checkForInvalidCountryCode];
    
    [IdentityBackupStore syncKeychainWithFile];
    
    [self cleanInbox];
    
    if (@available(iOS 17.0, *)) {
        [TipKitManager configureTips];
    }
}

#pragma mark - Storyboards

+ (UIStoryboard *)getLaunchStoryboard {
    NSString *storyboardName = [[BundleUtil mainBundle] objectForInfoDictionaryKey:@"UILaunchStoryboardName"];
    return [UIStoryboard storyboardWithName:storyboardName bundle:nil];
}

+ (UIStoryboard *)getMainStoryboard {
    return [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
}

+ (UIStoryboard *)getSettingsStoryboard {
    return [UIStoryboard storyboardWithName:@"SettingsStoryboard" bundle:nil];
}

+ (UIStoryboard *)getMyIdentityStoryboard {
    return [UIStoryboard storyboardWithName:@"MyIdentityStoryboard" bundle:nil];
}

+ (UITabBarController *)getMainTabBarController {
    AppDelegate *appDelegate = [AppDelegate sharedAppDelegate];
    UITabBarController *mainTabBar;

    if (SYSTEM_IS_IPAD && [appDelegate.window.rootViewController isKindOfClass:[SplitViewController class]]) {
        SplitViewController *splitViewController = (SplitViewController*)appDelegate.window.rootViewController;
        mainTabBar = (UITabBarController*)splitViewController.viewControllers[1];
    } else {
        mainTabBar = (UITabBarController*)appDelegate.window.rootViewController;
    }

    if ([mainTabBar isKindOfClass:[UITabBarController class]]) {
        return mainTabBar;
    } else {
        return nil;
    }
}

#pragma mark - UI handling

- (void)completedIDSetup {
    AppLaunchTasks *appLaunchTasks = [AppLaunchTasks new];
    [appLaunchTasks runLaunchEventDidFinishLaunching];
    
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if ((state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer) | ![[KKPasscodeLock sharedLock] isPasscodeRequired]) {
        [self presentApplicationUI];
        [self checkHasPrivateChats];
    } else {
        [self presentPasscodeView];
    }
        
    toaster = [[NewMessageToaster alloc] init];
    
    groupCallUIHelper = [GroupCallUIHelper new];
    [groupCallUIHelper setGlobalGroupCallsManagerSingletonUIDelegate];
}

- (void)checkHasPrivateChats {
   
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSArray *conversations = [entityManager.entityFetcher allConversations];
    BOOL hasPrivate = false;
    
    for (ConversationEntity *conversation in conversations) {
        if (conversation.category.intValue == ConversationCategoryPrivate) {
            hasPrivate = true;
            break;
        }
    }

    if (hasPrivate) {
        [UIAlertTemplate showAlertWithOwner:_window.rootViewController title:[BundleUtil localizedStringForKey:@"privateChat_alert_title"] message: [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"privateChat_setup_alert_message"], TargetManagerObjc.localizedAppName] titleOk:[BundleUtil localizedStringForKey:@"privateChat_code_alert_confirm"] actionOk:^(UIAlertAction * _Nonnull) {
            // No passcode is set, so we present it with the option to enable it
            JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
            vc.lockScreenMode = LockScreenModeNew;
            
            UINavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:vc];
            nav.navigationBarHidden = YES;
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
            [_window.rootViewController presentViewController:nav animated:YES completion:nil];
            
        } titleCancel:nil actionCancel:^(UIAlertAction * _Nonnull) {
            return;
        }];
    }

}

- (void)presentApplicationUI {
    [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    if ([self isAppInBackground] && isEnteringForeground == false) {
        shouldLoadUIForEnterForeground = true;
        UIStoryboard *launchStoryboard = [AppDelegate getLaunchStoryboard];
        self.window.rootViewController = [launchStoryboard instantiateInitialViewController];
    } else {
        if (lastViewController != nil) {
            if (lockView != nil) {
                [lockView removeFromSuperview];
            }
            self.window.rootViewController = lastViewController;

            lastViewController = nil;
            lockView = nil;
        }
        else if ([AppSetup isCompleted]) {
            if (UserSettings.sharedUserSettings.newNavigationEnabled) {
                appCoordinator = [[AppCoordinator alloc] initWithWindow:self.window];
            }
            else {
                if (SYSTEM_IS_IPAD) {
                    SplitViewController *splitViewController = [[SplitViewController alloc] init];
                    [splitViewController setup];
                    self.window.rootViewController = splitViewController;
                } else {
                    UIViewController *currentVC = self.window.rootViewController;
                    
                    if (![currentVC isKindOfClass:[MainTabBarController class]]) {
                        if (currentVC != nil) {
                            [currentVC dismissViewControllerAnimated:true completion:nil];
                        }
                        UIStoryboard *mainStoryboard = [AppDelegate getMainStoryboard];
                        self.window.rootViewController = [mainStoryboard instantiateInitialViewController];
                    }
                }
            }
        }
        
        // Do not use Sentry for onprem
        // OnPrem target has a macro with DISABLE_SENTRY
#ifndef DISABLE_SENTRY
        // Start crash report handler
        if (!ProcessInfoHelper.isRunningForScreenshots) {
            SentryClient *sentry = [[SentryClient alloc] init];
            [sentry start];
        }
#endif
        
        if (ProcessInfoHelper.isRunningForScreenshots) {
            [UserSettings sharedUserSettings].enableThreemaCall = true;
        }
        else {
            if (![ThreemaEnvironment supportsCallKit]) {
                [UserSettings sharedUserSettings].enableThreemaCall = false;
            }
        }
        
        [self updateIdentityInfo];
        
        if (![AppSetup isCompleted]) {
            return;
        }
        
        if (shouldLoadUIForEnterForeground == false) {
            if ([[WCSessionManager shared] isRunningWCSession] == true){
                DDLogNotice(@"[Threema Web] presentApplicationUI --> connect all running sessions");
            }
            [[WCSessionManager shared] connectAllRunningSessions];
        }

        deviceLinking = [DeviceLinking new];
        [deviceLinking disableMultiDeviceForVersionLessThan5];

        [AppDelegate setupConnection];
        
        /* Handle notification, if any */
        NSDictionary *remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification != nil) {
            [notificationManager handleThreemaNotificationWithPayload:remoteNotification receivedWhileRunning:NO notification:nil withCompletionHandler:nil];
        }
        
        if (![UserSettings sharedUserSettings].acceptedPrivacyPolicyDate) {
            [UserSettings sharedUserSettings].acceptedPrivacyPolicyDate = [NSDate date];
            [UserSettings sharedUserSettings].acceptedPrivacyPolicyVariant = AcceptPrivacyPolicyVariantUpdate;
        }
        
        if ([[UserSettings sharedUserSettings] openPlusIconInChat] == YES) {
            [[UserSettings sharedUserSettings] setOpenPlusIconInChat:NO];
            [[UserSettings sharedUserSettings] setShowGalleryPreview:NO];
        }

        [self handlePresentingScreensWithForce:NO];
        shouldLoadUIForEnterForeground = false;
        
    }
}

- (void)handlePresentingScreensWithForce:(BOOL)force {
    // ShouldLoadUIForEnterForeground == false: means UI was never loaded before
    if (shouldLoadUIForEnterForeground == false || force) {
        if (![NavigationBarPromptHandler isCallActiveInBackground] && [[VoIPCallStateManager shared] currentCallState] != CallStateIdle) {
            if ([lastViewController.presentedViewController isKindOfClass:[CallViewController class]] || SYSTEM_IS_IPAD) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
                });
            }
        } else {
            // Do not perform if we are running for screenshots
            if (ProcessInfoHelper.isRunningForScreenshots)  {
                return;
            }
                              
            // Perform Threema Safe launch checks
            SafeManager *safeManager = [[SafeManager alloc] initWithGroupManager:[[BusinessInjector new] groupManagerObjC]];
            [safeManager performThreemaSafeLaunchChecks];
        }
    }
}

- (UIViewController *)currentTopViewController {
    UIViewController *topVC = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

+ (UIAlertController *)isAlertViewShown {
    UIViewController *vc = [[[AppDelegate sharedAppDelegate] window] rootViewController];
    if ([vc.presentedViewController isKindOfClass:[UIAlertController class]]) {
        return (UIAlertController *)vc.presentedViewController;
    }
    
    return nil;
}

- (BOOL)isPresentingKeyGeneration {
    UIViewController *presentedVC = [self presentedCurrentViewController];
    if ([presentedVC isKindOfClass:[SplashViewController class]] || [presentedVC isKindOfClass:[RestoreOptionDataViewController class]] || [presentedVC isKindOfClass:[RestoreOptionBackupViewController class]] || [presentedVC isKindOfClass:[RestoreIdentityViewController class]]) {
        
        return YES;
    }
    
    return NO;
}

- (BOOL)isPresentingEnterLicense {
    __block UIViewController *presentedVC;
    if ([NSThread isMainThread]) {
        presentedVC = self.window.rootViewController.presentedViewController;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            presentedVC = self.window.rootViewController.presentedViewController;
        });
    }
    
    if ([presentedVC isKindOfClass:[EnterLicenseViewController class]]) {
        return YES;
    }
        
    return NO;
}

- (void)presentKeyGeneration {
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateID" bundle:[NSBundle mainBundle] ];
    UIViewController *createIdVC = [storyboard instantiateInitialViewController];
    
    self.window.rootViewController = createIdVC;
}

- (void)presentProtectedDataUnavailable {
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ProtectedDataUnavailable" bundle:[NSBundle mainBundle] ];
    UIViewController *unavailableVC = [storyboard instantiateInitialViewController];
    
    self.window.rootViewController = unavailableVC;
}

- (void)presentIDBackupRestore {
    UIViewController *presentedVC = [self presentedCurrentViewController];
    if ([presentedVC isKindOfClass:[SplashViewController class]]) {
        [((SplashViewController *)presentedVC) showRestoreIdentityViewController];
    } else if ([presentedVC isKindOfClass:[RestoreOptionBackupViewController class]]) {
        [((SplashViewController *)[((RestoreOptionBackupViewController *)presentedVC) parentViewController]) showRestoreIdentityViewController];
    } else if ([presentedVC isKindOfClass:[RestoreIdentityViewController class]]) {
        [((RestoreIdentityViewController *)presentedVC) updateTextViewWithBackupCode];
    }
}

- (void)presentKeyGenerationOrProtectedDataUnavailable {
    if ([[MyIdentityStore sharedMyIdentityStore] isKeychainLocked]) {
        [self presentProtectedDataUnavailable];
    } else {
        [self presentKeyGeneration];
    }
}

- (UIViewController *)presentedCurrentViewController {
    UIViewController *presentedVC = self.window.rootViewController.presentedViewController;
    if (presentedVC == nil && [self.window.rootViewController.childViewControllers count] > 0) {
        presentedVC = self.window.rootViewController.childViewControllers[0];
    } else if (presentedVC == nil) {
        presentedVC = self.window.rootViewController;
    }
    return presentedVC;
}

- (void)handleLicenseMissing:(NSNotification*)notification {
    if (!TargetManagerObjc.isBusinessApp) {
        return;
    }
    
    EnterLicenseViewController *viewController = [EnterLicenseViewController instantiate];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self closeMainTabBarModalViewsWithCompletion:^{
            [self closeRootViewControllerModalViewsWithCompletion:^{
                [UIView animateWithDuration:0.0 animations:^{
                    if ([AppDelegate isAlertViewShown]) {
                        [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
                            [self presentEnterLicenseViewController:viewController];
                        }];
                    } else {
                        [self presentEnterLicenseViewController:viewController];
                    }
                }];
            }];
        }];
    });
}

- (void)presentEnterLicenseViewController:(EnterLicenseViewController *)viewController {
    viewController.delegate = self;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[WCSessionManager shared] stopAndForgetAllSessions];
    
    [self.window.rootViewController presentViewController:viewController animated:NO completion:nil];
}

- (void)showLockScreen {
        
    /* Replace the root view controller to ensure it's not visible in snapshots */
    if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
        if (![lockView isDescendantOfView:self.window]) {
            if ([self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
                if (![[[nav childViewControllers] objectAtIndex:0] isKindOfClass:[JKLLockScreenViewController class]]) {
                    lastViewController = self.window.rootViewController;
                }
            } else {
                if (![self.window.rootViewController isKindOfClass:[JKLLockScreenViewController class]]) {
                    lastViewController = self.window.rootViewController;
                }
            }
            
            [lastViewController.view endEditing:YES];
            [lastViewController.presentedViewController.view endEditing:YES];
            
            if ([lastViewController.presentedViewController isKindOfClass:[CallViewController class]]) {
                [lastViewController dismissViewControllerAnimated:NO completion:nil];
            }
            
            UIViewController *lockCover = [[UIViewController alloc] initWithNibName:@"LockCover" bundle:nil];
            lockView = lockCover.view;
            lockView.frame = self.window.bounds;

            [self.window insertSubview:lockView atIndex:99999];
            [self.window bringSubviewToFront:lockView];
            [self.window snapshotViewAfterScreenUpdates:false];
            
            isLockscreenDismissed = false;
        } else {
            // This Prevents overriding the current view with a lockscreen, thus ending in an infinite loop
            if ([self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
                if (![[[nav childViewControllers] objectAtIndex:0] isKindOfClass:[JKLLockScreenViewController class]]) {
                    lastViewController = self.window.rootViewController;
                }
            } else {
                if (![self.window.rootViewController isKindOfClass:[JKLLockScreenViewController class]]) {
                    lastViewController = self.window.rootViewController;
                }
            }
            [self.window bringSubviewToFront:lockView];
            [self.window snapshotViewAfterScreenUpdates:false];
        }
    }
}

- (void)updateTheme API_AVAILABLE(ios(13.0)) {
    if ([[UserSettings sharedUserSettings] useSystemTheme]) {
        if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            if (Colors.theme != ThemeDark) {
                [Colors setTheme:ThemeDark];
            }
        } else {
            if (Colors.theme != ThemeLight) {
                [Colors setTheme:ThemeLight];
            }
        }
        [[NotificationPresenterWrapper shared] colorChanged];
    }
}

- (void)setIsWorkContactsLoading:(BOOL)loading {
    isWorkContactsLoading = loading;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationLoadWorkContacts object:nil];

}

#pragma mark - Server Connection and Notifications

+ (void)setupConnection {
    // Add received pushes into DB
    if (![[AppDelegate sharedAppDelegate] isAppInBackground]) {
        [[ServerConnector sharedServerConnector] setIsAppInBackground:NO];

        // Maybe is already connected, called by identity created
        if ([[ServerConnector sharedServerConnector] connectionState] == ConnectionStateDisconnecting || [[ServerConnector sharedServerConnector] connectionState] == ConnectionStateDisconnected) {
            [[ServerConnector sharedServerConnector] connect:ConnectionInitiatorApp onCompletion:nil];
        }
    }
        
    [FeatureMask updateLocalObjc];

    [AppDelegate registerForLocalNotifications];
}

+ (void)registerForLocalNotifications {
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionProvidesAppNotificationSettings) completionHandler:^(__unused BOOL granted, NSError * _Nullable error)
     {
        
        if (!granted) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [[ServerConnector sharedServerConnector] removePushToken];
            });
            return;
        }
        
         if( !error ) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [[UIApplication sharedApplication] registerForRemoteNotifications];
             });
             
             NotificationActionProvider* provider = [NotificationActionProvider new];
             NSSet* categories = [provider defaultCategories];
             [center setNotificationCategories:categories];
         }
     }];
    
}

#pragma mark - Misc

- (BOOL)isAppInBackground {
    __block BOOL inBackground = false;
    if ([NSThread isMainThread]) {
        inBackground = [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            inBackground = [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground;
        });
    }
    
    return inBackground;
}

- (void)checkForInvalidCountryCode {
    if ([PhoneNumberNormalizer userRegion] != nil)
        return;

    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:[BundleUtil localizedStringForKey:@"invalid_country_code_title"] message:[BundleUtil localizedStringForKey:@"invalid_country_code_message"] actionOk:nil];
}

- (void)updateIdentityInfo {
    MyIdentityStore *identityStore = [MyIdentityStore sharedMyIdentityStore];
    
    /* We have an identity, but is the (user defaults based) private identity info current?
     If the user deletes and reinstalls the app, the keychain data will be maintained, but
     the user defaults will be missing */
    if (identityStore.identity != nil && identityStore.privateIdentityInfoLastUpdate == nil) {
        DDLogInfo(@"Missing private identity info; fetching from server");
        ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
        [apiConnector updateMyIdentityStore:identityStore onCompletion:^{
            identityStore.privateIdentityInfoLastUpdate = [NSDate date];
        } onError:^(NSError *error) {
            DDLogError(@"Private identity info update failed: %@", error);
        }];
    }
}

/**
 Selector method to process update all contacts in background thread, to prevent blocking the app, otherwise will killed by watchdog.
*/
- (void)updateAllContacts {
    [[ContactStore sharedContactStore] updateAllContacts];
}

- (void)cleanPushDirectory {
    // clean directory with push images
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [NSString stringWithFormat:@"%@/PushImages", cache];
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
}

- (void)cleanInbox {
    // Clean Documents/Inbox directory (old files may accumulate there in case of aborted document share operations),
    // but only if we haven't been opened to share a URL
    if (launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        [self removeDirectoryContents:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Inbox"]];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[FileUtility shared] cleanTemporaryDirectoryWithOlderThan:nil];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [CallHistoryManager removeCallsOlderThanChatServerTimeout];
        });
    }
}

- (void)removeDirectoryContents:(NSString*)directory {
    DDLogInfo(@"Remove contents of %@", directory);
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:nil]) {
        [fm removeItemAtPath:[directory stringByAppendingPathComponent:file] error:nil];
    }
}

-(void)registerMemoryWarningNotifications {
    [[NSNotificationCenter defaultCenter] addObserverForName:
     UIApplicationDidReceiveMemoryWarningNotification
     object:[UIApplication sharedApplication] queue:nil
     usingBlock:^(__unused NSNotification *notif) {
        DDLogWarn(@"Received Memory Warning");
    }];
}

#pragma mark - Application delegates

- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
    DDLogNotice(@"AppState: applicationWillResignActive");
    self.active = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        notificationManager.firstPushHandled = false;
    });
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    application.shortcutItems = [UIApplicationShortcutItemProvider itemsFor:mdmSetup];
    
    [self showLockScreen];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    DDLogNotice(@"AppState: applicationDidEnterBackground");
    
    [[ThreemaBGTaskManager shared] scheduleTasks];
    [self showLockScreen];
    
    if (![AppSetup isCompleted]) {
        return;
    }

    if (!isAppLocked) {
        [[KKPasscodeLock sharedLock] updateLastUnlockTime];

        /* replace the root view controller to ensure it's not visible in snapshots */
        if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
            isAppLocked = YES;
        }
    } else {
        NSInteger state = [[VoIPCallStateManager shared] currentCallState];
        if (isAppLocked && (state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer)) {
            if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
                isAppLocked = YES;
            }
        }
    }
    
    // If protected data is not available, then there's no point in starting a background task.
    if (!protectedDataWillBecomeUnavailable) {
        
        BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
        NSString *key = nil;
        int timeout = 0;
        
        if ([[VoIPCallStateManager shared] currentCallState] != CallStateIdle) {
            // Call is active
            key = kAppVoIPBackgroundTask;
            timeout = kAppVoIPIncomCallBackgroundTaskTime;
        }
        else if ([[WCSessionManager shared] isRunningWCSession] == true) {
            // Web client is active
            key = kAppWCBackgroundTask;
            timeout = kAppWCBackgroundTaskTime;
        }
        else if ([Old_FileMessageSender hasScheduledUploads] == YES || [manager hasActiveSyncs] || ![TaskManager isEmpty]) {

            // Queue is not empty
            key = kAppClosedByUserBackgroundTask;
            timeout = kAppSendingBackgroundTaskTime;
        }
        else {
            key = kAppClosedByUserBackgroundTask;
            timeout = kAppClosedByUserBackgroundTaskTime;
        }

        [[BackgroundTaskManager shared] newBackgroundTaskWithKey:key timeout:timeout completionHandler:nil];
    } else {
        // Disconnect from server - from now on we want push notifications for new messages
        [[ServerConnector sharedServerConnector] disconnectWait:ConnectionInitiatorApp];
    }
    
    // This is needed to keep the notification actions up to date
    [AppDelegate registerForLocalNotifications];
    
    [SettingsBundleHelper resetSafeMode];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    DDLogNotice(@"AppState: applicationWillEnterForeground");
    
    if (![AppSetup isCompleted]) {
        return;
    }

    AppLaunchTasks *appLaunchTasks = [AppLaunchTasks new];
    [appLaunchTasks runLaunchEventWillEnterForeground];

    // Reload pending user notification cache, because could be changed by Notification Extension in the mean time
    if (incomingMessageManager) {
        [incomingMessageManager reloadPendingUserNotificationCache];
    }

    [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppClosedByUserBackgroundTask];
    [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppWCBackgroundTask];

    isEnteringForeground = true;
    BOOL shouldLoadUI = true;

    if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && [NavigationBarPromptHandler isCallActiveInBackground]) {
        [self presentPasscodeView];
        shouldLoadUI = false;
    }
    else if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && [[VoIPCallStateManager shared] currentCallState] != CallStateIncomingRinging && [[VoIPCallStateManager shared] currentCallState] != CallStateOutgoingRinging && [[VoIPCallStateManager shared] currentCallState] != CallStateInitializing && [[VoIPCallStateManager shared] currentCallState] != CallStateCalling && [[VoIPCallStateManager shared] currentCallState] != CallStateReconnecting) {
        [self presentPasscodeView];
        shouldLoadUI = false;
    }
    else {
        if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && ([[VoIPCallStateManager shared] currentCallState] == CallStateIncomingRinging || [[VoIPCallStateManager shared] currentCallState] == CallStateOutgoingRinging || [[VoIPCallStateManager shared] currentCallState] == CallStateInitializing || [[VoIPCallStateManager shared] currentCallState] == CallStateCalling || [[VoIPCallStateManager shared] currentCallState] == CallStateReconnecting)) {
            if ([lastViewController.presentedViewController isKindOfClass:[CallViewController class]] || SYSTEM_IS_IPAD) {
                [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
                [self presentApplicationUI];
                shouldLoadUI = false;
            }
            if (SYSTEM_IS_IPAD) {
                [[VoIPCallStateManager shared] presentCallViewController];
                shouldLoadUI = false;
            }
        }
    }
    
    if (shouldLoadUIForEnterForeground == true && shouldLoadUI == true) {
        [self performSelectorOnMainThread:@selector(presentApplicationUI) withObject:nil waitUntilDone:YES];
        [self performSelectorOnMainThread:@selector(updateAllContacts) withObject:nil waitUntilDone:NO];
    }
    else if (TargetManagerObjc.isBusinessApp) {
        // check again for threema safe if a url have changed in mdm
        [self handlePresentingScreensWithForce:YES];        
    }

    /* ensure we're connected when we enter into foreground */
    [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    if ([[WCSessionManager shared] isRunningWCSession] == true){
        DDLogNotice(@"[Threema Web] applicationWillEnterForeground --> connect all running sessions");
    }
    
    [[WCSessionManager shared] connectAllRunningSessions];

    [[DatabaseManager dbManager] refreshDirtyObjects: YES];
    
    [[ServerConnector sharedServerConnector] connect:ConnectionInitiatorApp onCompletion:nil];
    [FeatureMask updateLocalObjc];
    [AppDelegate registerForLocalNotifications];
    
    [[TypingIndicatorManager sharedInstance] resetTypingIndicators];
    [[NotificationPresenterWrapper shared] dismissAllPresentedNotifications];
    
    if ([[UserSettings sharedUserSettings] enableThreemaGroupCalls]) {
        [[GlobalGroupCallManagerSingleton shared] loadCallsFromDBWithCompletionHandler:^{
            // Noop
        }];
    }
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
    DDLogInfo(@"AppState: applicationProtectedDataWillBecomeUnavailable");

    protectedDataWillBecomeUnavailable = YES;

    if ([[WCSessionManager shared] isRunningWCSession] == false) {
        [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppClosedByUserBackgroundTask];
    }
}

- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application {
    DDLogInfo(@"AppState: applicationProtectedDataDidBecomeAvailable");
    protectedDataWillBecomeUnavailable = NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    DDLogNotice(@"AppState: applicationDidBecomeActive");

    if (migrating || requiresMigration == RequiresMigrationError) {
        return;
    }
    if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && isAppLocked) {
        if (![self isPassCodeViewControllerPresented]) {
            [self presentPasscodeView];
        } else {
            if (lockView != nil) {
                [lockView removeFromSuperview];
            }
        }
    } else {
        if (lockView != nil) {
            [self performSelectorOnMainThread:@selector(presentApplicationUI) withObject:nil waitUntilDone:YES];
        }
    }

    self.active = YES;
    
    [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    if (![AppSetup isCompleted]) {
        return;
    }
    
    // set language and mdm description for client version string
    (void)[ThreemaUtility clientVersion];
    
    [self updateTheme];

    [[ServerConnector sharedServerConnector] setIsAppInBackground:[application applicationState] == UIApplicationStateBackground];

    [notificationManager updateUnreadMessagesCount];

    // Remove notifications from center
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];

    if (ProcessInfoHelper.isRunningForScreenshots)  {
        NSMutableOrderedSet *workIdentities = [NSMutableOrderedSet new];

        if (TargetManagerObjc.isBusinessApp) {
            [workIdentities addObject:@"H3BK2FVH"];
            [workIdentities addObject:@"JYNBZX53"];
            [workIdentities addObject:@"RFH4BE5C"];
        }
        [workIdentities addObject:@"J3KK7X69"];
        [UserSettings sharedUserSettings].workIdentities = workIdentities;
    } else {
        [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:NO onCompletion:nil onError:nil];
    }

    [self setIsWorkContactsLoading:true];
    [WorkDataFetcher checkUpdateWorkDataForce:NO onCompletion:^{
        [self setIsWorkContactsLoading:false];
    } onError:^(NSError *error) {
        [self setIsWorkContactsLoading:false];
    }];
    
    [[GatewayAvatarMaker gatewayAvatarMaker] refresh];
    
    if ([[VoIPCallStateManager shared] currentCallState] != CallStateIdle && ![NavigationBarPromptHandler isCallActiveInBackground]) {
        [[VoIPCallStateManager shared] presentCallViewController];
    } else {
        // If not a call, then trigger Threema Safe backup (it will show an alert here, if last successful backup older than 7 days)
        SafeManager *safeManager = [[SafeManager alloc]initWithGroupManager:[[BusinessInjector new] groupManagerObjC]];
        [safeManager initTrigger];
    }
    
    [self cleanPushDirectory];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    DDLogNotice(@"AppState: applicationWillTerminate");
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window {
    return orientationLock;
}

#pragma mark - Intent handling

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *restorationHandler))restorationHandler {
    if([userActivity.activityType isEqualToString:@"INSendMessageIntent"]) {
        return [self handleINSendMessageIntentWithUserActivity:userActivity];
    } else if ([userActivity.activityType isEqualToString:@"INStartAudioCallIntent"]) {
        return [self handleStartAudioCallIntent:userActivity];
    } else if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        [URLHandler handleURL:userActivity.webpageURL];
    }
    return NO;
}

- (BOOL)handleStartAudioCallIntent:(NSUserActivity*)userActivity {
    INInteraction *interaction = userActivity.interaction;
    INStartAudioCallIntent *startAudioCallIntent = (INStartAudioCallIntent *)interaction.intent;
    INPerson *person = startAudioCallIntent.contacts[0];
    INPersonHandle *personHandle = person.personHandle;
    if (personHandle.value) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        ContactEntity *contact = [entityManager.entityFetcher contactForId:personHandle.value];
        if (contact) {
            [FeatureMask checkWithIdentities:[NSSet setWithObjects:personHandle.value, nil] for:FEATURE_MASK_VOIP completion:^(NSArray *unsupportedContacts) {
                if (unsupportedContacts.count == 0) {
                    VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:ActionCall contactIdentity:contact.identity callID:nil completion:nil];
                    [[VoIPCallStateManager shared] processUserAction:action];
                } else {
                    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"call_voip_not_supported_title"], TargetManagerObjc.localizedAppName] message:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"call_voip_not_supported_text"], TargetManagerObjc.localizedAppName] actionOk:nil];
                }
            }];
        }
    }
    return YES;
}

+ (BOOL)hasBottomSafeAreaInsets {
    return [[[[UIApplication sharedApplication] delegate] window] safeAreaInsets].bottom > 0;
}


#pragma mark - Push notifications

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DDLogWarn(@"Push registration failed: %@", error);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [[ServerConnector sharedServerConnector] setPushToken:deviceToken];
    // TODO: IOS-3014: Removed alert to ask for pushDecrypt (preview in notifs, also take care of MDM_KEY_DISABLE_MESSAGE_PREVIEW and comm notifs)
}

#pragma mark - UNUserNotificationCenterDelegate

/**
 Is not allowed when could not evaluate requires DB migration or DB migration is running or App setup is not finished yet.
 @param doBeforeExit: Will be running before possible exit
 */
- (BOOL)isHandleNotificationAllowed:(void(^ _Nullable)(void))doBeforeExit {
    if (migrating || ![AppSetup isCompleted]) {
        return NO;
    }
    else {
        if (requiresMigration == RequiresMigrationError) {
            DDLogError(@"Exit App because could not evaluate requiering DB migration");
            if (doBeforeExit != nil) {
                doBeforeExit();
            }
            exit(0);
            return NO;
        }
    }
    return YES;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    if ([self isHandleNotificationAllowed:^{
        completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound);
    }] == YES) {
        if (!_active && ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle || ![[VoIPCallStateManager shared] preCallHandling])) {
            DDLogNotice(@"[Push] willPresentNotification: Start NotificationExtension for received push");
            DDLogNotice(@"[Push] App active: %i, CallState: %i, PreCallHandling: %i", _active, [[VoIPCallStateManager shared] currentCallState] == CallStateIdle, [[VoIPCallStateManager shared] preCallHandling]);
            // Do not handle notifications if the app is not active -> Show notification in iOS, not in the app
            completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound);
        }
        else {
            DDLogNotice(@"[Push] willPresentNotification: Handle notification for received push");
            [notificationManager handleThreemaNotificationWithPayload:notification.request.content.userInfo receivedWhileRunning:YES notification:notification withCompletionHandler:completionHandler];
        }
    }
    else {
        DDLogNotice(@"[Push] willPresentNotification: Handle notification is not allowed");
        completionHandler(UNNotificationPresentationOptionNone);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    if ([self isHandleNotificationAllowed:nil] == YES) {
        // Decrypt Threema payload if necessary
        NotificationResponse *notificationResponse = [[NotificationResponse alloc] initWithResponse:response completion:completionHandler];
        [notificationResponse handleNotificationResponse];
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
    rootToNotificationSettings = true;
    MainTabBarController *mainTabBarController = [AppDelegate getMainTabBarController];
    [UIApplication.sharedApplication.windows.firstObject.rootViewController dismissViewControllerAnimated:false completion:nil];
    [mainTabBarController showNotificationSettings];
}


#pragma mark - URL & shortcut handling

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    DDLogVerbose(@"openURL: %@", url);

    if (isAppLocked) {
        pendingUrl = url;
        return YES;
    }

    return [URLHandler handleURL:url];
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {

    BOOL result = NO;
    if (isAppLocked) {
        pendingShortCutItem = shortcutItem;
    } else {
        result = [URLHandler handleShortCutItem:shortcutItem];
    }

    completionHandler(result);
}

#pragma mark - UI passcode

- (BOOL)isPassCodeViewControllerPresented {
    UINavigationController *navVC;
    UIViewController *rootVC = self.window.rootViewController;
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        navVC = (UINavigationController *) rootVC;
    } else {
        navVC = self.window.rootViewController.navigationController;
    }
    
    return [navVC.topViewController isKindOfClass:[JKLLockScreenViewController class]];
}

- (void)presentPasscodeView {
    if (lockView != nil) {
        [lockView removeFromSuperview];
    }
    BOOL isCallViewControllerPresented = [self.window.rootViewController.presentedViewController isKindOfClass:[CallViewController class]];
    if (isAppLocked && [[KKPasscodeLock sharedLock] isWithinGracePeriod]) {
        [self dismissPasscodeViewAnimated:NO];
    } else if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && [self isPassCodeViewControllerPresented] == NO) {
        JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
        vc.lockScreenMode = LockScreenModeNormal;
        vc.delegate = self;
        
        /* dismiss modal view controller, if any */
        if (!isCallViewControllerPresented) {
            [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        }
        
        UINavigationController *nav = [[UINavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
        nav.navigationBarHidden = YES;
        [nav pushViewController:vc animated:NO];
        isAppLocked = YES;
        self.window.rootViewController = nav;
    }
    
    if (isAppLocked && !isCallViewControllerPresented) {
        if ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle || [NavigationBarPromptHandler isCallActiveInBackground]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                [self tryTouchIdAuthentication];
            });
        }
    }
}

- (void)dismissPasscodeViewAnimated:(BOOL)animated {
    if (!isAppLocked)
        return;
    
    isAppLocked = NO;
    startCheckBiometrics = false;
    isLockscreenDismissed = true;
    
    [self.window.rootViewController dismissViewControllerAnimated:animated completion:nil];
    
    if (![AppSetup isCompleted]) {
        [self presentKeyGenerationOrProtectedDataUnavailable];
        return;
    }
    
    [self completeAuthentication];
}

- (void)completeAuthentication {
    [self presentApplicationUI];
    
    if (pendingUrl) {
        [URLHandler handleURL:pendingUrl];
        pendingUrl = nil;
    } else if (pendingShortCutItem) {
        [URLHandler handleShortCutItem:pendingShortCutItem];
        pendingShortCutItem = nil;
    }
    
    if (evaluatedPolicyDomainState != nil) {
        [[UserSettings sharedUserSettings] setEvaluatedPolicyDomainStateApp:evaluatedPolicyDomainState];
        evaluatedPolicyDomainState = nil;
    }
    
    if (rootToNotificationSettings) {
        MainTabBarController *mainTabBarController = [AppDelegate getMainTabBarController];
        [UIApplication.sharedApplication.windows.firstObject.rootViewController dismissViewControllerAnimated:false completion:nil];
        [mainTabBarController showNotificationSettings];
        rootToNotificationSettings = nil;
    }
}

- (void)tryTouchIdAuthentication {
    if ([[KKPasscodeLock sharedLock] isTouchIdOn]) {
        startCheckBiometrics = true;
    }
    
    [TouchIDAuthentication tryTouchIDAuthenticationCallback:^(BOOL success, NSError *error, NSData *evaluatePolicyStateData) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                DDLogVerbose(@"Authenticated using Touch ID.");
                [self dismissPasscodeViewAnimated:YES];
            } else {
                DDLogVerbose(@"Touch ID error: %@", error);
                if ([[error domain] isEqual: @"ThreemaErrorDomain"]) {
                    LAContext *context = [LAContext new];
                    NSString* title = @"";
                    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
                        if (context.biometryType == LABiometryTypeFaceID) {
                            title = [BundleUtil localizedStringForKey:@"alert_biometrics_changed_title_face"];
                        } else {
                            title = [BundleUtil localizedStringForKey:@"alert_biometrics_changed_title_touch"];
                        }
                    }
                    
                    evaluatedPolicyDomainState = evaluatePolicyStateData;
                    [UIAlertTemplate showAlertWithOwner:_window.rootViewController title:title message:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"alert_biometrics_changed_message"], TargetManagerObjc.appName, TargetManagerObjc.appName] actionOk:^(UIAlertAction * _Nonnull) {
                        return;
                    }];
                }
            }
        });
    }];
}


#pragma mark - Passcode lock delegate

- (void)shouldEraseApplicationData:(JKLLockScreenViewController *)viewController {
    [self eraseApplicationData];
}

- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController *)viewController {
    isAppLocked = NO;
    startCheckBiometrics = false;

    [self completeAuthentication];
}

- (void)didPasscodeViewDismiss:(JKLLockScreenViewController *)viewController {
    /* At this point, it's possible that there's no ID but the view controller to generate the key
     has been dismissed because the passcode view was presented. Therefore, we need to present the
     generate controller again */
    isLockscreenDismissed = true;
    if (![AppSetup isCompleted]) {
        [self presentKeyGenerationOrProtectedDataUnavailable];
    }
}

- (BOOL)allowTouchIDLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController {
    startCheckBiometrics = [[KKPasscodeLock sharedLock] isTouchIdOn];
    return [[KKPasscodeLock sharedLock] isTouchIdOn];
}


#pragma mark - Erase Data

- (void)eraseApplicationData {
    // Hide all views
    [self closeMainTabBarModalViewsWithCompletion:^{
        [self closeRootViewControllerModalViewsWithCompletion:^{
            [UIView animateWithDuration:0.0 animations:^{
                [self removeAllControllersFromRoot];
            } completion:^(BOOL finished) {
                // Delete all data then show summary
                [DeleteRevokeIdentityManager deleteLocalDataObjCWithCompletion:^{
                    self.window.rootViewController = [SwiftUIAdapter createDeleteSummaryView];
                }];
            }];
        }];
    }];
}

- (void)closeMainTabBarModalViewsWithCompletion:(nonnull void (^)(void))completion {
    MainTabBarController *mainTabBar = (MainTabBarController *)[AppDelegate getMainTabBarController];
    
    if (mainTabBar.presentedViewController != nil) {
        [mainTabBar dismissViewControllerAnimated:NO completion:completion];
    } else {
        completion();
    }
}

- (void)closeRootViewControllerModalViewsWithCompletion:(nonnull void (^)(void))completion {
    if (self.window.rootViewController.presentedViewController != nil) {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:completion];
    } else {
        completion();
    }
}

- (void)removeAllControllersFromRoot {
    MainTabBarController *mainTabBar = (MainTabBarController *)[AppDelegate getMainTabBarController];
    for (UINavigationController *navController in mainTabBar.viewControllers) {
        [navController popToRootViewControllerAnimated:false];
        navController.viewControllers = @[];
    }
    
    if (SYSTEM_IS_IPAD && [self.window.rootViewController isKindOfClass:[SplitViewController class]]) {
        SplitViewController *splitViewController = (SplitViewController*)self.window.rootViewController;

        PortraitNavigationController *pNav = splitViewController.viewControllers[0];
        pNav.viewControllers = @[];
        
        splitViewController.viewControllers = @[];
    }
    
    self.window.rootViewController = nil;
}

#pragma mark - EnterLicenseDelegate

- (void)licenseConfirmed {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[ServerConnector sharedServerConnector] setIsAppInBackground:[[AppDelegate sharedAppDelegate] isAppInBackground]];
        [[ServerConnector sharedServerConnector] connect:ConnectionInitiatorApp onCompletion:nil];
    }];
}

#pragma mark - Accessibility

- (BOOL)accessibilityPerformMagicTap {
    return [self.magicTapHandler handleMagicTap];
}


#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    if([credentials.token length] == 0) {
        DDLogNotice(@"Token is null");
        return;
    }

    if (type == PKPushTypeVoIP) {
        // Remove VoIP push token (since min OS version is iOS 15 or above)
        [[ServerConnector sharedServerConnector] removeVoIPPushToken];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(nonnull PKPushType)type withCompletionHandler:(nonnull void (^)(void))completion {
    [self handlePushPayload:payload withCompletionHandler:completion];
}

- (void)handlePushPayload:(PKPushPayload*)payload withCompletionHandler:(nonnull void (^)(void))completion {
    // If alive check is received via voip push, do nothing and call the completion block
    BOOL isAliveCheck = [payload.dictionaryPayload[@"threema"][@"alive-check"] isEqual: @1];
    VoIPCallStateManager *voIPCallStateManager = [VoIPCallStateManager shared];

    if (migrating ||
        ![AppSetup isCompleted] ||
        requiresMigration != RequiresMigrationNone ||
        isAliveCheck) {
        
        NSString *appName = [BundleUtil localizedStringForKey: [TargetManagerObjc appName]];
        [voIPCallStateManager startAndCancelCallFrom: appName showWebNotification:false completion:completion];
        return;
    }
    
    if (payload.dictionaryPayload[@"NotificationExtensionOffer"]) {
        DDLogNotice(@"didReceiveIncomingPushWithPayload from NotificationService");
    } else {
        DDLogNotice(@"didReceiveIncomingPushWithPayload: %@", payload.dictionaryPayload);
    }
    
    [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    [voIPCallStateManager startInitialIncomingCallWithDictionaryPayload: payload.dictionaryPayload completion:^(BOOL succeeded) {
        if (succeeded) {
            [notificationManager handleVoipPushWithPayload:payload.dictionaryPayload withCompletionHandler:^(BOOL isThreemaDict, NSDictionary * _Nullable handlerPayload) {
                if (handlerPayload == nil) {
                    completion();
                    return;
                }

                if (!isThreemaDict) {
                    [incomingMessageManager incomingPushWithPayloadDic:handlerPayload completion:completion];
                }
                else {
                    [incomingMessageManager incomingPushWithThreemaDic:handlerPayload completion:^{
                        if (self.isAppInBackground) {
                            [[ServerConnector sharedServerConnector] connectWait:ConnectionInitiatorThreemaCall];
                        }
                        completion();
                    }];
                }
            }];
        }
        else {
            completion();
        }
    }];
}


// pragma mark: Other Functions

- (void)eraseApplicationData:(JKLLockScreenViewController *)viewController {

    DDLogWarn(@"Erase all application data");

    [[MyIdentityStore sharedMyIdentityStore] destroy];
    [UserReminder markIdentityAsDeleted];

    /* Remove Core Data stuff */
    [[DatabaseManager dbManager] eraseDB];

    /* Remove files */
    [self removeDirectoryContents:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    [self removeDirectoryContents:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    [self removeDirectoryContents:NSTemporaryDirectory()];

    /* Reset defaults and turn off passcode */
    [NSUserDefaults resetStandardUserDefaults];
    [AppGroup resetUserDefaults];
    
    // Unregister APNS Push Token
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    });

    [[KKPasscodeLock sharedLock] disablePasscode];

    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];

    NSString *title = [BundleUtil localizedStringForKey:@"all_data_deleted_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"all_data_deleted_message"];

    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
        exit(0);
    }];
}
@end
