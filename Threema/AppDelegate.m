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

#import <CommonCrypto/CommonCrypto.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "AppDelegate.h"
#import "NaClCrypto.h"
#import "ServerConnector.h"
#import "MyIdentityStore.h"
#import "MessageQueue.h"
#import "ContactStore.h"
#import "Conversation.h"
#import "UIDefines.h"
#import "ServerAPIConnector.h"
#import "UserSettings.h"
#import "TypingIndicatorManager.h"
#import "StatusNavigationBar.h"
#import "MyIdentityStore.h"
#import "PortraitNavigationController.h"
#import "UserReminder.h"
#import "Utils.h"
#import "Contact.h"
#import "ContactsViewController.h"
#import "ProtocolDefines.h"
#import "PhoneNumberNormalizer.h"
#import "AbstractGroupMessage.h"
#import "NSString+Hex.h"
#import "SVProgressHUD.h"
#import "NewMessageToaster.h"
#import "EntityFetcher.h"
#import "SplitViewController.h"
#import "GatewayAvatarMaker.h"
#import "ErrorHandler.h"
#import "DatabaseManager.h"
#import "FeatureMask.h"
#import "TouchIdAuthentication.h"
#import "ErrorNotificationHandler.h"
#import "SplashViewController.h"

#import "MessageProcessor.h"
#import "MessageProcessorProxy.h"
#import "BackgroundTaskManagerProxy.h"

#import "NotificationManager.h"

#import "SDNetworkActivityIndicator.h"
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

#import "BaseMessage.h"
#import "BoxBallotCreateMessage.h"
#import "BallotMessageDecoder.h"
#import "BoxImageMessage.h"
#import "ImageMessage.h"
#import "GroupImageMessage.h"
#import "BoxVideoMessage.h"
#import "VideoMessage.h"
#import "GroupVideoMessage.h"
#import "DocumentManager.h"
#import "MessageSender.h"
#import "EntityManager.h"
#import "VoIPHelper.h"
#import "PushPayloadDecryptor.h"
#import "Threema-Swift.h"
#import "ConversationUtils.h"
#import "ThreemaFramework.h"

#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>
#import <Intents/Intents.h>

#import "ValidationLogger.h"

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
    BOOL isEnterForeground;
    BOOL startCheckBiometrics;
    UIView *lockView;
}

@synthesize window = _window;
@synthesize urlRestoreData;
@synthesize appLaunchDate;
@synthesize isAppLocked;
@synthesize isLockscreenDismissed;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [AppGroup setGroupId:THREEMA_GROUP_IDENTIFIER];
        [AppGroup setAppId:APP_ID];
        
#ifdef DEBUG
        [LogManager initializeGlobalLoggerWithDebug:YES];
#else
        [LogManager initializeGlobalLoggerWithDebug:NO];
#endif

        // Initialize app setup state (checking database file exists) as early as possible
        (void)[[AppSetupState alloc] init];
    });
}

+ (AppDelegate*)sharedAppDelegate {
    __block AppDelegate *appDelegate = nil;
    if ([NSThread isMainThread]) {
        [AppDelegate initAppDelegate];
        appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [AppDelegate initAppDelegate];
            appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        });
    }
    
    return appDelegate;
}

+ (void)initAppDelegate {
    [ActivityIndicatorProxy wireActivityIndicator:[SDNetworkActivityIndicator sharedActivityIndicator]];
    [MessageProcessorProxy wireMessageProcessor:[MessageProcessor sharedMessageProcessor]];
    [BackgroundTaskManagerProxy wireBackgroundTaskManager:[BackgroundTaskManager shared]];
}

#pragma mark - Launching

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)_launchOptions
{
    shouldLoadUIForEnterForeground = false;
    isEnterForeground = false;
    databaseImported = false;
    startCheckBiometrics = false;
    launchOptions = _launchOptions;
    isLockscreenDismissed = true;

    [ErrorNotificationHandler setup];

    appLaunchDate = [NSDate date];

    [NotificationManager sharedInstance];
    
    DDLogNotice(@"AppState: didFinishLaunchingWithOptions");

    /* Instantiate various singletons now */
    [NaClCrypto sharedCrypto];
    [ServerConnector sharedServerConnector];

    [[PendingMessagesManager shared] setup];

    /* Observe connection status */
    [[ServerConnector sharedServerConnector] addObserver:self forKeyPath:@"connectionState" options:0 context:nil];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    pendingShortCutItem = [launchOptions objectForKey:UIApplicationLaunchOptionsShortcutItemKey];

    [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];

    PKPushRegistry *pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    pushRegistry.delegate = self;
    pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLicenseMissing:) name:kNotificationLicenseMissing object:nil];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
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
    if (([dbManager storeRequiresImport] || requiresMigration == RequiresMigration) && [self isAppInBackground]) {
        [NotificationManager showNoAccessToDatabaseNotification];
        return NO;
    }
    
    if ([dbManager storeRequiresImport]) {
        DDLogVerbose(@"Store will be import and start migration");
        migrating = YES;
        
        [self performSelectorOnMainThread:@selector(launchImportDatabase) withObject:nil waitUntilDone:NO];
    } else {
        if (requiresMigration == RequiresMigrationError) {
            [Utils sendErrorLocalNotification:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_title"] body:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_description"] userInfo:@{@"threema": @{@"cmd": @"error", @"error": @"migration"}}];
            return NO;
        }
        else if (requiresMigration == RequiresMigration) {
            DDLogVerbose(@"Store requires migration");
            migrating = YES;
            
            /* run phase 2 (which involves migration) separately to avoid getting killed with "failed to launch in time" */
            [self performSelectorOnMainThread:@selector(launchPhase2) withObject:nil waitUntilDone:NO];
        } else {
            /* run phase 3 immediately */
            [self launchPhase3];
        }
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        NSString *theme = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme"];
        if ([LicenseStore requiresLicenseKey] == YES) {
            if ([theme isEqualToString:@"dark"]) {
                [Colors setTheme:ColorThemeDarkWork];
            } else {
                [Colors setTheme:ColorThemeLightWork];
            }
        } else {
            if ([theme isEqualToString:@"dark"]) {
                [Colors setTheme:ColorThemeDark];
            } else {
                [Colors setTheme:ColorThemeLight];
            }
        }
        [[UserSettings sharedUserSettings] setEnableCallKit:false];
    }
    
    if (@available(iOS 13.0, *)) {
        if ([UserSettings sharedUserSettings].useSystemTheme == false && _window.overrideUserInterfaceStyle == UIUserInterfaceStyleUnspecified) {
            switch ([Colors getTheme]) {
                case ColorThemeDark:
                case ColorThemeDarkWork:
                    _window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
                    break;
                default:
                    _window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
                    break;
            }
        } else {
            if ([UserSettings sharedUserSettings].useSystemTheme == true && _window.overrideUserInterfaceStyle != UIUserInterfaceStyleUnspecified) {
                _window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            }
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
    [SVProgressHUD showWithStatus:NSLocalizedString(@"updating_database", nil)];

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
                [SVProgressHUD dismiss];
                [ErrorHandler abortWithError: storeError additionalText:@"Failed to import database"];
                /* do not run launchPhase3 at this point, as we shouldn't load the main storyboard and cause any database accesses */
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (requiresMigration == RequiresMigrationError) {
                    [Utils sendErrorLocalNotification:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_title"] body:[BundleUtil localizedStringForKey:@"error_message_requires_migration_error_description"] userInfo:nil];
                }
                else if (requiresMigration == RequiresMigration) {
                    DDLogVerbose(@"Store requires migration");
                    databaseImported = YES;
                    /* run phase 2 (which involves migration) separately to avoid getting killed with "failed to launch in time" */
                    [self performSelectorOnMainThread:@selector(launchPhase2) withObject:nil waitUntilDone:NO];
                } else {
                    [SVProgressHUD dismiss];
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
    if (databaseImported == false) {
        WizardBackgroundView *migrationBgView = [[WizardBackgroundView alloc] initWithFrame:self.window.frame];
        migrationBgView.contentMode = UIViewContentModeScaleAspectFill;
        [self.window addSubview:migrationBgView];
        [self.window makeKeyAndVisible];
    }

    /* check disk space first */
    if ([[DatabaseManager dbManager] canMigrateDB] == NO) {
        return;
    }

    if (databaseImported == false) {
        /* display spinner during migration */
        [SVProgressHUD showWithStatus:NSLocalizedString(@"updating_database", nil)];
    }
    /* run migration now in background */
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].idleTimerDisabled = YES;
        });
        DatabaseManager *dbManager = [DatabaseManager dbManager];
        [dbManager doMigrateDB];

        NSError *storeError = [dbManager storeError];
        if (storeError != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                [ErrorHandler abortWithError: storeError additionalText:NSLocalizedString(@"database_migration_error_hints", nil)];
                /* do not run launchPhase3 at this point, as we shouldn't load the main storyboard and cause any database accesses */
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
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
    
    // apply MDM parameter anyway, perhaps company MDM has changed
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    [mdmSetup loadRenewableValues];
    
    [AppDelegate sharedAppDelegate];

    /* generate key pair and register with server if not existing */
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        [self presentKeyGenerationOrProtectedDataUnavailable];
        [self.window makeKeyAndVisible];
        return;
    }
    
    if ([[DatabaseManager dbManager] shouldUpdateProtection]) {
        MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
        [myIdentityStore updateConnectionRights];
        [[DatabaseManager dbManager] updateProtection];
    }
    
    [[ContactStore sharedContactStore] updateAllContactsToCNContact];
        
    [NotificationManager generatePushSettingForAllGroups];
    
    [TypingIndicatorManager sharedInstance];
    
    [[KKPasscodeLock sharedLock] setDefaultSettings];
    [[KKPasscodeLock sharedLock] upgradeAccessibility];
    [KKPasscodeLock sharedLock].attemptsAllowed = 10;
    
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    
    if ((state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer) | ![[KKPasscodeLock sharedLock] isPasscodeRequired]) {
         [self presentApplicationUI];
     } else {
         [self presentPasscodeView];
     }
    
    [self.window makeKeyAndVisible];
    
    toaster = [[NewMessageToaster alloc] init];
    
    if (shouldLoadUIForEnterForeground == false) {
        [self performSelectorOnMainThread:@selector(updateAllContacts) withObject:nil waitUntilDone:NO];
    }
    
    [self checkForInvalidCountryCode];
    
    [IdentityBackupStore syncKeychainWithFile];
    
    [self cleanInbox];
}

#pragma mark - Storyboards

+ (UIStoryboard *)getLaunchStoryboard {
    if ([LicenseStore requiresLicenseKey] == NO) {
        return [UIStoryboard storyboardWithName:@"ThreemaLaunchScreen" bundle:nil];
    } else {
        return [UIStoryboard storyboardWithName:@"ThreemaWorkLaunchScreen" bundle:nil];
    }
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

- (void)fixTabBarNotBeingHidden {
    // reselect chat bar in order to trigger hiding of tab bar again
    UITabBarController *mainTabBarController = [AppDelegate getMainTabBarController];
    if (mainTabBarController.selectedIndex == kChatTabBarIndex) {
        mainTabBarController.selectedIndex = kContactsTabBarIndex;
        mainTabBarController.selectedIndex = kChatTabBarIndex;
    }
}

- (void)completedIDSetup {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if ((state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer) | ![[KKPasscodeLock sharedLock] isPasscodeRequired]) {
        [self presentApplicationUI];
    } else {
        [self presentPasscodeView];
    }
    toaster = [[NewMessageToaster alloc] init];
}

- (void)presentApplicationUI {
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    if ([self isAppInBackground] && isEnterForeground == false) {
        shouldLoadUIForEnterForeground = true;
        UIStoryboard *launchStoryboard = [AppDelegate getLaunchStoryboard];
        self.window.rootViewController = [launchStoryboard instantiateInitialViewController];
    } else {
        if (lastViewController != nil) {
            if (lockView != nil) {
                [lockView removeFromSuperview];
            }
            self.window.rootViewController = lastViewController;
            [self fixTabBarNotBeingHidden];

            lastViewController = nil;
            lockView = nil;
        } else if (SYSTEM_IS_IPAD) {
            SplitViewController *splitViewController = [[SplitViewController alloc] init];
            [splitViewController setup];
            self.window.rootViewController = splitViewController;
        } else {
            UIViewController *currentVC = self.window.rootViewController;
            if (currentVC != nil) {
                [currentVC dismissViewControllerAnimated:true completion:nil];
            }
            UIStoryboard *mainStoryboard = [AppDelegate getMainStoryboard];
            self.window.rootViewController = [mainStoryboard instantiateInitialViewController];
        }

        // Start crash report handler
        SentryClient *sentry = [[SentryClient alloc] init];
        [sentry start];
        
        [self updateIdentityInfo];
        [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];

        [MessageQueue sharedMessageQueue];
        
        [AppDelegate setupConnection];
        
        /* Handle notification, if any */
        NSDictionary *remoteNotification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification != nil) {
            [self handleRemoteNotification:remoteNotification receivedWhileRunning:NO notification:nil];
        }

        if (shouldLoadUIForEnterForeground == false) {
            if ([[WCSessionManager shared] isRunningWCSession] == true){
                DDLogNotice(@"Threema Web: presentApplicationUI --> connect all running sessions");
            }
            [[WCSessionManager shared] connectAllRunningSessions];
        }

        /* A good chance to show reminders, if necessary */
        [[UserReminder sharedUserReminder] checkReminders:^(BOOL check) {
            if (![UserSettings sharedUserSettings].acceptedPrivacyPolicyDate) {
                [UserSettings sharedUserSettings].acceptedPrivacyPolicyDate = [NSDate date];
                [UserSettings sharedUserSettings].acceptedPrivacyPolicyVariant = AcceptPrivacyPolicyVariantUpdate;
            }
            
            if ([[UserSettings sharedUserSettings] openPlusIconInChat] == YES) {
                [[UserSettings sharedUserSettings] setOpenPlusIconInChat:NO];
                [[UserSettings sharedUserSettings] setShowGalleryPreview:NO];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] unregisterForRemoteNotifications];
            });
            
            [self handlePresentingScreens];
            shouldLoadUIForEnterForeground = false;
        }];
    }
}

- (void)handlePresentingScreens {
    //shouldLoadUIForEnterForeground == false: means UI was never loaded before
    if (shouldLoadUIForEnterForeground == false) {
        if (![[VoIPHelper shared] isCallActiveInBackground] && [[VoIPCallStateManager shared] currentCallState] != CallStateIdle) {
            if ([lastViewController.presentedViewController isKindOfClass:[CallViewController class]] || SYSTEM_IS_IPAD) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
                });
            }
        } else {
            // show Threema Safe Intro once after App update
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
                // do not show threema safe intro
            } else {
                // Check if backup is forced from MDM
                SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
                SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init]];
                SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeApiService:[[SafeApiService alloc] init]];
                MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
                
                // check if Threema Safe is forced and not activated yet
                if (![safeManager isActivated] && [mdmSetup isSafeBackupForce]) {
                    if ([mdmSetup safePassword] == nil) {
                        // show password without cancel button for Threema Safe
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
                            UIStoryboard *storyboard = [AppDelegate getMyIdentityStoryboard];
                            UINavigationController *safeSetupNavigationViewController = [storyboard instantiateViewControllerWithIdentifier:@"SafeIntroNavigationController"];
                            SafeSetupPasswordViewController *safeSetupPasswordViewController = (SafeSetupPasswordViewController*)[safeSetupNavigationViewController topViewController];
                            safeSetupPasswordViewController.isForcedBackup = true;
                            [vc presentViewController:safeSetupNavigationViewController animated:YES completion:nil];
                        });
                    } else {
                        // activate with the password of the MDM
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            // or if password is already set from MDM (automaticly perform safe)
                            NSString *customServer = nil;
                            NSString *server = nil;
                            if ([mdmSetup isSafeBackupServerPreset]) {
                                // server is given by MDM
                                customServer = [mdmSetup safeServerUrl];
                                server = [safeStore composeSafeServerAuthWithServer:[mdmSetup safeServerUrl] user:[mdmSetup safeServerUsername] password:[mdmSetup safeServerPassword]].absoluteString;
                            }
                            NSError *error;
                            
                            [safeManager activateWithIdentity:[MyIdentityStore sharedMyIdentityStore].identity password:[mdmSetup safePassword] customServer:customServer server:server maxBackupBytes:nil retentionDays:nil error:&error];
                        });
                    }
                }
                // if Threema Safe is disabled by MDM and Safe is activated, deactivate Safe
                else if ([safeManager isActivated] && [mdmSetup isSafeBackupDisable]) {
                    [safeManager deactivate];
                }
                // if Safe activated, check if server has been changed by MDM
                else if ([safeManager isActivated] && [mdmSetup isManaged]) {
                    if ([mdmSetup isSafeBackupServerPreset]) {
                        [safeManager applyServerWithServer:[mdmSetup safeServerUrl] username:[mdmSetup safeServerUsername] password:[mdmSetup safeServerPassword]];
                    } else {
                        [safeManager applyServerWithServer:nil username:nil password:nil];
                    }
                }
                else {
                    // if Safe not activated and not disabled by MDM, show intro if is necessary
                    if ([[UserSettings sharedUserSettings] safeIntroShown] == NO && ![safeManager isActivated] && ![mdmSetup isSafeBackupDisable]) {
                        [[UserSettings sharedUserSettings] setSafeIntroShown:YES];

                        if (![safeManager isActivated]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
                                UIStoryboard *storyboard = [AppDelegate getMyIdentityStoryboard];
                                UIViewController *safeIntroViewController = [storyboard instantiateViewControllerWithIdentifier:@"SafeIntroViewController"];
                                [vc presentViewController:safeIntroViewController animated:YES completion:nil];
                            });
                        }
                    }
                }
            }
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
        [WorkDataFetcher checkUpdateThreemaMDM:^{
        } onError:^(NSError *error) {
        }];
        [self presentKeyGeneration];
    }
}

- (void)askForPushDecryption {
    if (![UserSettings sharedUserSettings].askedForPushDecryption) {
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
        if ([mdmSetup existsMdmKey:MDM_KEY_DISABLE_MESSAGE_PREVIEW]) {
            [[UserSettings sharedUserSettings] setPushDecrypt:NO];
        } else {
            UIAlertController * alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"decryption_push_title", nil) message:NSLocalizedString(@"decryption_push_text", nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* yesButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"decryption_push_activate", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                [[UserSettings sharedUserSettings] setPushDecrypt:YES];
                [[UserSettings sharedUserSettings] setAskedForPushDecryption:YES];
            }];
            
            UIAlertAction* noButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"decryption_push_deactivate", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                [[UserSettings sharedUserSettings] setPushDecrypt:NO];
                [[UserSettings sharedUserSettings] setAskedForPushDecryption:YES];
            }];
            
            [alert addAction:yesButton];
            [alert addAction:noButton];
            
            [_window.rootViewController presentViewController:alert animated:YES completion:nil];
        }
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
    if ([LicenseStore requiresLicenseKey] == NO) {
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"License" bundle:nil];
    
    EnterLicenseViewController *viewController = [storyboard instantiateInitialViewController];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.window.rootViewController isKindOfClass:[viewController class]] == NO) {
            
            if ([AppDelegate isAlertViewShown]) {
                [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
                    [self presentEnterLicenseViewController:viewController];
                }];
            } else {
                [self presentEnterLicenseViewController:viewController];
            }
        }
    });
}

- (void)presentEnterLicenseViewController:(EnterLicenseViewController *)viewController {
    viewController.delegate = self;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [[WCSessionManager shared] stopAndForgetAllSessions];
    
    [self.window.rootViewController presentViewController:viewController animated:NO completion:nil];
}

- (void)showLockScreen {
    /* replace the root view controller to ensure it's not visible in snapshots */
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
            
            UIViewController *lockCover = nil;
            if ([LicenseStore requiresLicenseKey] == YES) {
                lockCover = [[UIViewController alloc] initWithNibName:@"LockCoverWork" bundle:nil];
            } else {
                lockCover = [[UIViewController alloc] initWithNibName:@"LockCover" bundle:nil];
            }
            
            lockView = lockCover.view;
            lockView.frame = self.window.bounds;

            [self.window insertSubview:lockView atIndex:99999];
            [self.window bringSubviewToFront:lockView];
            [self.window snapshotViewAfterScreenUpdates:false];
            
            isLockscreenDismissed = false;
        } else {
            [self.window bringSubviewToFront:lockView];
            [self.window snapshotViewAfterScreenUpdates:false];
        }
    }
}

#pragma mark - Server Connection and Notifications

+ (void)setupConnection {
    // Add received pushes into DB
    if (![[AppDelegate sharedAppDelegate] isAppInBackground]) {
        [[ServerConnector sharedServerConnector] connect];
    }
    [FeatureMask updateFeatureMask];

    [AppDelegate registerForLocalNotifications];
}

+ (void)registerForLocalNotifications {
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error)
     {
         if( !error ) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 [[UIApplication sharedApplication] registerForRemoteNotifications];
             });
             
             // required to get the app to do anything at all about push notifications
             UNTextInputNotificationAction *textAction = [UNTextInputNotificationAction actionWithIdentifier:@"REPLY_MESSAGE" title:NSLocalizedString(@"decryption_push_reply", nil) options:UNNotificationActionOptionAuthenticationRequired textInputButtonTitle:NSLocalizedString(@"send", nil) textInputPlaceholder:NSLocalizedString(@"decryption_push_placeholder", nil)];
             
             UNNotificationAction *thumbUpAction = [UNNotificationAction actionWithIdentifier:@"THUMB_UP" title:NSLocalizedString(@"decryption_push_agree", nil) options:UNNotificationActionOptionAuthenticationRequired];
             UNNotificationAction *thumbDownAction = [UNNotificationAction actionWithIdentifier:@"THUMB_DOWN" title:NSLocalizedString(@"decryption_push_disagree", nil) options:UNNotificationActionOptionAuthenticationRequired];
             
             UNTextInputNotificationAction *callReplyAction = [UNTextInputNotificationAction actionWithIdentifier:@"REPLY_MESSAGE" title:NSLocalizedString(@"decryption_push_reply", nil) options:UNNotificationActionOptionAuthenticationRequired textInputButtonTitle:NSLocalizedString(@"send", nil) textInputPlaceholder:NSLocalizedString(@"decryption_push_placeholder", nil)];
             UNNotificationAction *callBackAction = [UNNotificationAction actionWithIdentifier:@"CALL" title:NSLocalizedString(@"call_back", nil) options:UNNotificationActionOptionForeground];
             
             UNNotificationAction *acceptCallAction = [UNNotificationAction actionWithIdentifier:@"ACCEPTCALL" title:NSLocalizedString(@"call_accept", nil) options:UNNotificationActionOptionForeground];
             UNNotificationAction *rejectCallAction = [UNNotificationAction actionWithIdentifier:@"REJECTCALL" title:NSLocalizedString(@"call_reject", nil) options:UNNotificationActionOptionDestructive];
             
             // Create the category with the custom actions.
             UNNotificationCategory *singleCategory = [UNNotificationCategory categoryWithIdentifier:@"SINGLE" actions:@[textAction, thumbUpAction, thumbDownAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
             UNNotificationCategory *groupCategory = [UNNotificationCategory categoryWithIdentifier:@"GROUP" actions:@[textAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
             UNNotificationCategory *callCategory = [UNNotificationCategory categoryWithIdentifier:@"CALL" actions:@[callReplyAction, callBackAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
             UNNotificationCategory *incomCallCategory = [UNNotificationCategory categoryWithIdentifier:@"INCOMCALL" actions:@[acceptCallAction, rejectCallAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
             
             // Register the notification categories.
             [center setNotificationCategories:[NSSet setWithObjects:groupCategory, singleCategory, callCategory, incomCallCategory, nil]];
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

    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:NSLocalizedString(@"invalid_country_code_title", nil) message:NSLocalizedString(@"invalid_country_code_message", nil) actionOk:nil];
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
 Selector method to process update all contacts in backgropund thread, to prevent blocking the app, otherwise will killed by watchdog.
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
            [FileUtility cleanTemporaryDirectoryWithOlderThan:nil];
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
        self.firstPushHandled = false;
    });
    
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        return;
    }
    
    [self showLockScreen];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    DDLogNotice(@"AppState: applicationDidEnterBackground");
    
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        return;
    }
    
    [self showLockScreen];

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
    
    /* Is protected data still available? If not, then there's no point in starting a background task */
    if (!protectedDataWillBecomeUnavailable) {
        NSString *key = nil;
        int timeout = 0;
        if ([[WCSessionManager shared] isRunningWCSession] != true) {
            key = kAppClosedByUserBackgroundTask;
            timeout = kAppClosedByUserBackgroundTaskTime;
        } else {
            key = kAppWCBackgroundTask;
            timeout = kAppWCBackgroundTaskTime;
        }
        
        [[BackgroundTaskManager shared] newBackgroundTaskWithKey:key timeout:timeout completionHandler:^{
            [[MessageQueue sharedMessageQueue] save];
            [[PendingMessagesManager shared] save];
            [[WCSessionManager shared] saveSessionsToArchive];
        }];
    } else {
        /* Disconnect from server - from now on we want push notifications for new messages */
        [[ServerConnector sharedServerConnector] disconnectWait];
        
        [[MessageQueue sharedMessageQueue] save];
        [[WCSessionManager shared] saveSessionsToArchive];
        [[PendingMessagesManager shared] save];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    DDLogNotice(@"AppState: applicationWillEnterForeground");
    
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        return;
    }

    [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppClosedByUserBackgroundTask];
    [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppWCBackgroundTask];

    isEnterForeground = true;
    BOOL shouldLoadUI = true;

    if ([[KKPasscodeLock sharedLock] isPasscodeRequired] && [[VoIPHelper shared] isCallActiveInBackground]) {
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

    [[DatabaseManager dbManager] refreshDirtyObjects];

    /* ensure we're connected when we enter into foreground */
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    if ([[WCSessionManager shared] isRunningWCSession] == true){
        [[ValidationLogger sharedValidationLogger] logString:@"Threema Web: applicationWillEnterForeground --> connect all running sessions"];
    }
    [[WCSessionManager shared] connectAllRunningSessions];

    [[ServerConnector sharedServerConnector] connect];
    [[TypingIndicatorManager sharedInstance] resetTypingIndicators];
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

    if (migrating) {
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
    
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        return;
    }

    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];

    // Remove notifications from center
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        NSMutableOrderedSet *workIdentities = [NSMutableOrderedSet new];

        if ([LicenseStore requiresLicenseKey] == YES) {
            [workIdentities addObject:@"H3BK2FVH"];
            [workIdentities addObject:@"JYNBZX53"];
            [workIdentities addObject:@"RFH4BE5C"];
        }
        [workIdentities addObject:@"J3KK7X69"];
        [UserSettings sharedUserSettings].workIdentities = workIdentities;
    } else {
        [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:NO onCompletion:nil onError:nil];
    }

    [WorkDataFetcher checkUpdateWorkDataForce:NO onCompletion:nil onError:nil];
    
    [[GatewayAvatarMaker gatewayAvatarMaker] refresh];
    
    if ([[VoIPCallStateManager shared] currentCallState] != CallStateIdle && ![VoIPHelper shared].isCallActiveInBackground) {
        [[VoIPCallStateManager shared] presentCallViewController];
    } else {
        // if not a call, then trigger Threema Safe backup (it will show an alert here, if last successful backup older than 7 days)
        SafeConfigManager *safeConfigManager = [[SafeConfigManager alloc] init];
        SafeStore *safeStore = [[SafeStore alloc] initWithSafeConfigManagerAsObject:safeConfigManager serverApiConnector:[[ServerAPIConnector alloc] init]];
        SafeManager *safeManager = [[SafeManager alloc] initWithSafeConfigManagerAsObject:safeConfigManager safeStore:safeStore safeApiService:[[SafeApiService alloc] init]];
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

    [[MessageQueue sharedMessageQueue] save];
    [[PendingMessagesManager shared] save];
    [[WCSessionManager shared] saveSessionsToArchive];
}

#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [ServerConnector sharedServerConnector] && [keyPath isEqualToString:@"connectionState"]) {
        DDLogInfo(@"Server connection state changed to %@", [[ServerConnector sharedServerConnector] nameForConnectionState:[ServerConnector sharedServerConnector].connectionState]);
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Server connection state changed to %@", [[ServerConnector sharedServerConnector] nameForConnectionState:[ServerConnector sharedServerConnector].connectionState]]];
    }
}

#pragma mark - Audio call intent

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *restorationHandler))restorationHandler {
    if ([userActivity.activityType isEqualToString:@"INStartAudioCallIntent"]) {
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
        Contact *contact = [entityManager.entityFetcher contactForId:personHandle.value];
        if (contact) {
            [FeatureMask checkFeatureMask:FEATURE_MASK_VOIP forContacts:[NSSet setWithObjects:contact, nil] onCompletion:^(NSArray *unsupportedContacts) {
                if (unsupportedContacts.count == 0) {
                    VoIPCallUserAction *action = [[VoIPCallUserAction alloc] initWithAction:ActionCall contact:contact callId:nil completion:nil];
                    [[VoIPCallStateManager shared] processUserAction:action];
                } else {
                    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:NSLocalizedString(@"call_voip_not_supported_title", nil) message:NSLocalizedString(@"call_voip_not_supported_text", nil) actionOk:nil];
                }
            }];
        }
    }
    return YES;
}

+ (BOOL)hasBottomSafeAreaInsets {
    if (@available(iOS 11.0, *)) {
        return [[[[UIApplication sharedApplication] delegate] window] safeAreaInsets].bottom > 0;
    } else {
        return false;
    }
}


#pragma mark - Push notifications

/**
 Is not allowed when could not evaluate requiers DB migration or DB migration is running or App setup is not finished yet.
 @param doBeforExit: Will be running before possible exit
 */
- (BOOL)isHandleNotificationAllowed:(void(^ _Nullable)(void))doBeforeExit {
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (migrating || ![appSetupState isAppSetupCompleted]) {
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

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DDLogWarn(@"Push registration failed: %@", error);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [self askForPushDecryption];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    if ([self isHandleNotificationAllowed:^{
        completionHandler(UNNotificationPresentationOptionAlert|UNNotificationPresentationOptionBadge|UNNotificationPresentationOptionSound);
    }] == YES) {
        NSDictionary *userInfo = notification.request.content.userInfo;
        [self handleRemoteNotification:userInfo receivedWhileRunning:true notification:notification];
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    if ([self isHandleNotificationAllowed:nil] == YES) {
        // Decrypt Threema payload if necessary
        NotificationResponse *notificationResponse = [[NotificationResponse alloc] initWithResponse:response completion:completionHandler];
        [notificationResponse handleNotificationResponse];
    }
}

- (void)handleRemoteNotification:(NSDictionary*)userInfo receivedWhileRunning:(BOOL)receivedWhileRunning notification:(UNNotification *)notification {
    EntityManager *entityManager = [[EntityManager alloc] init];
    if (!receivedWhileRunning) {
        NSDictionary *threemaDict = [userInfo objectForKey:@"threema"];
        if (threemaDict != nil) {
            // Decrypt Threema payload if necessary
            threemaDict = [PushPayloadDecryptor decryptPushPayload:threemaDict];

            NSString *cmd = [threemaDict objectForKey:@"cmd"];
            if (cmd != nil) {
                if ([cmd isEqualToString:@"newmsg"] || [cmd isEqualToString:@"missedcall"]) {
                    /* New message push - switch to appropriate conversation */
                    NSString *from = [threemaDict objectForKey:@"from"];
                    if (from != nil) {
                        Contact *contact = [entityManager.entityFetcher contactForId:from];
                        if (contact != nil) {
                            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  contact, kKeyContact,
                                                  [NSNumber numberWithBool:YES], kKeyForceCompose,
                                                  nil];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (!self.firstPushHandled)     {
                                        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
                                        self.firstPushHandled = true;
                                    }
                                });
                        }
                    }
                } else if ([cmd isEqualToString:@"newgroupmsg"]) {
                    NSString *from = [threemaDict objectForKey:@"from"];
                    if (from != nil) {
                        Contact *contact = [entityManager.entityFetcher contactForId:from];
                        if (contact != nil) {
                            /* Try to find an appropriate group - if there is only one conversation in which
                             the sender is a member, then it must be the right one. Otherwise we cannot know */
                            NSString *groupId = [threemaDict objectForKey:@"groupId"];
                            if (groupId != nil) {
                                
                                Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:[[NSData alloc] initWithBase64EncodedString:groupId options:0]];
                                if (conversation != nil) {
                                    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                                          conversation, kKeyConversation,
                                                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                                                          nil];
                                    
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            if (!self.firstPushHandled) {
                                                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
                                                self.firstPushHandled = true;
                                            }
                                        });
                                }
                            } else {
                                NSArray *groups = [entityManager.entityFetcher conversationsForMember:contact];
                                if (groups.count == 1) {
                                    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                                          [groups objectAtIndex:0], kKeyConversation,
                                                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                                                          nil];
                                    
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            if (!self.firstPushHandled) {
                                                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
                                                self.firstPushHandled = true;
                                            }
                                        });
                                }
                            }
                        }
                    }
                }
            }
        }
    } else {
        if ([[userInfo objectForKey:@"key"] isEqualToString:@"safe-backup-notification"] && notification != nil) {
            [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:notification.request.content.title message:notification.request.content.body actionOk:nil];
        }
    }
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
        
        UINavigationController *nav;
        if (SYSTEM_IS_IPAD) {
            nav = [[UINavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
        } else {
            nav = [[UINavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
        }
        nav.navigationBarHidden = YES;
        [nav pushViewController:vc animated:NO];
        isAppLocked = YES;
        self.window.rootViewController = nav;
    }
    
    if (isAppLocked && !isCallViewControllerPresented) {
        if ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle || [VoIPHelper shared].isCallActiveInBackground) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                [self tryTouchIdAuthentication];
            });
        }
    }
}

- (void)dismissPasscodeViewAnimated:(BOOL)animated {
    if (!isAppLocked)
        return;
    
    [self.window.rootViewController dismissViewControllerAnimated:animated completion:nil];
    [self presentApplicationUI];
    
    isAppLocked = NO;
    startCheckBiometrics = false;
    isLockscreenDismissed = true;
    
    if (pendingUrl) {
        [URLHandler handleURL:pendingUrl];
        pendingUrl = nil;
    } else if (pendingShortCutItem) {
        [URLHandler handleShortCutItem:pendingShortCutItem];
        pendingShortCutItem = nil;
    }
}

- (void)tryTouchIdAuthentication {
    if ([[KKPasscodeLock sharedLock] isTouchIdOn]) {
        startCheckBiometrics = true;
    }
    
    [TouchIdAuthentication tryTouchIdAuthenticationCallback:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                DDLogVerbose(@"Authenticated using Touch ID.");
                [self dismissPasscodeViewAnimated:YES];
            } else {
                DDLogVerbose(@"Touch ID error: %@", error);
            }
        });
    }];
}



#pragma mark - Passcode lock delegate

- (void)shouldEraseApplicationData:(JKLLockScreenViewController *)viewController {

    DDLogWarn(@"Erase all application data");

    [[MyIdentityStore sharedMyIdentityStore] destroy];
    [[UserReminder sharedUserReminder] markIdentityDeleted];

    /* Remove Core Data stuff */
    [[DatabaseManager dbManager] eraseDB];

    /* Remove files */
    [self removeDirectoryContents:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    [self removeDirectoryContents:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]];
    [self removeDirectoryContents:NSTemporaryDirectory()];

    /* Reset defaults and turn off passcode */
    [NSUserDefaults resetStandardUserDefaults];
    [AppGroup resetUserDefaults];

    [[KKPasscodeLock sharedLock] disablePasscode];

    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];

    NSString *title = [BundleUtil localizedStringForKey:@"all_data_deleted_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"all_data_deleted_message"];

    [UIAlertTemplate showAlertWithOwner:[self currentTopViewController] title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
        exit(0);
    }];
}

- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController *)viewController {
    isAppLocked = NO;
    startCheckBiometrics = false;

    [self presentApplicationUI];

    if (pendingUrl) {
        [URLHandler handleURL:pendingUrl];
        pendingUrl = nil;
    } else if (pendingShortCutItem) {
        [URLHandler handleShortCutItem:pendingShortCutItem];
        pendingShortCutItem = nil;
    }
}

- (void)didPasscodeViewDismiss:(JKLLockScreenViewController *)viewController {
    /* At this point, it's possible that there's no ID but the view controller to generate the key
     has been dismissed because the passcode view was presented. Therefore, we need to present the
     generate controller again */
    isLockscreenDismissed = true;
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupState isAppSetupCompleted]) {
        [self presentKeyGenerationOrProtectedDataUnavailable];
    }
    
}

- (BOOL)allowTouchIDLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController {
    startCheckBiometrics = [[KKPasscodeLock sharedLock] isTouchIdOn];
    return [[KKPasscodeLock sharedLock] isTouchIdOn];
}

#pragma mark - EnterLicenseDelegate

- (void)licenseConfirmed {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[ServerConnector sharedServerConnector] connect];
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
        [[ServerConnector sharedServerConnector] setVoIPPushToken:credentials.token];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(nonnull PKPushType)type {   
    [self handlePushPayload:payload withCompletionHandler:^{}];
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(nonnull PKPushType)type withCompletionHandler:(nonnull void (^)(void))completion {
    [self handlePushPayload:payload withCompletionHandler:completion];
}

- (void)handlePushPayload:(PKPushPayload*)payload withCompletionHandler:(nonnull void (^)(void))completion {
    AppSetupState *appSetupState = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (migrating || ![appSetupState isAppSetupCompleted] || requiresMigration != RequiresMigrationNone) {
        completion();
        return;
    }
    
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"didReceiveIncomingPushWithPayload: %@", payload.dictionaryPayload]];
    [[BackgroundTaskManager shared] newBackgroundTaskWithKey:kAppPushBackgroundTask timeout:kAppPushBackgroundTaskTime completionHandler:^{
        [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
        [[NotificationManager sharedInstance] handleVoIPPush:payload.dictionaryPayload withCompletionHandler:completion];
    }];
}

@end
