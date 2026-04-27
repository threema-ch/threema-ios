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
#import "ProtocolDefines.h"
#import "PhoneNumberNormalizer.h"
#import "AbstractGroupMessage.h"
#import "NSString+Hex.h"
#import "NewMessageToaster.h"
#import "GatewayAvatarMaker.h"
#import "ErrorHandler.h"
#import "TouchIdAuthentication.h"
#import "SplashViewController.h"

#import "ActivityIndicatorProxy.h"
#import "BundleUtil.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "EnterLicenseViewController.h"
#import "WorkDataFetcher.h"

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
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>
#import <Intents/Intents.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <MBProgressHUD/MBProgressHUD.h>
@import FileUtility;
@import Keychain;

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@interface AppDelegate () <EnterLicenseDelegate, PKPushRegistryDelegate>

@end

@implementation AppDelegate  {
    NSDictionary *launchOptions;
    BOOL databaseImported;
    BOOL protectedDataWillBecomeUnavailable;
    NewMessageToaster *toaster;
    UIViewController *lastViewController;
    BOOL shouldLoadUIForEnterForeground;
    BOOL isEnteringForeground;
    BOOL startCheckBiometrics;
    BOOL rootToNotificationSettings;
    UIView *lockView;
    IncomingMessageManager *incomingMessageManager;
    NotificationManager *notificationManager;
    NSData *evaluatedPolicyDomainState;
    GroupCallUIHelper *groupCallUIHelper;
    AppCoordinator *_appCoordinator;
}

@synthesize window = _window;
@synthesize launchTaskManager;
@synthesize isBusinessInjectorReady;
@synthesize urlRestoreData;
@synthesize appLaunchDate;
@synthesize isAppLocked;
@synthesize pendingUrl;
@synthesize pendingShortCutItem;
@synthesize orientationLock;
@synthesize isWorkContactsLoading;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [AppGroup setGroupId:[BundleUtil threemaAppGroupIdentifier]];
        [AppGroup setAppId:[[BundleUtil mainBundle] bundleIdentifier]];
        [FileUtilityObjCSetter setInitialFileUtility];

#ifdef DEBUG
        [LogManager initializeGlobalLoggerWithDebug:YES];
#else
        [LogManager initializeGlobalLoggerWithDebug:NO];
#endif
        // Checking database file exists as early as possible
        [AppSetup registerIfADatabaseFileExists];
    });
}

#pragma mark - Properties

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

- (id)appCoordinator {
    return _appCoordinator;
}

#pragma mark - Launching

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)_launchOptions
{
    isAppLocked = YES;
    launchTaskManager = [LaunchTaskManager new];
    // Initializing this will also register all tasks, see documentation for more info.
    [ThreemaBGTaskManager shared];

    [self registerLifetimeObservers];
    [PromiseKitConfiguration configurePromiseKit];

    shouldLoadUIForEnterForeground = false;
    isEnteringForeground = false;
    databaseImported = false;
    startCheckBiometrics = false;
    launchOptions = _launchOptions;
    isWorkContactsLoading = false;
    orientationLock = UIInterfaceOrientationMaskAll;

    ErrorNotificationHandler *errorNotificationHandler = [ErrorNotificationHandler shared];

    appLaunchDate = [NSDate date];

    DDLogNotice(@"AppState: didFinishLaunchingWithOptions");
    [DebugLog logAppVersion];

    /* Instantiate various singletons now */
    [NaClCrypto sharedCrypto];
    [[ServerConnector sharedServerConnector] setIsAppInBackground:[self isAppInBackground]];

    self.window = [[ThemedWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    if (ProcessInfoHelper.isRunningForScreenshots) {
        [[UserSettings sharedUserSettings] setIncludeCallsInRecents:false];
        [UIView setAnimationsEnabled:false];
    }

    [Colors resolveTheme];
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
        [AVAudioApplication requestRecordPermissionWithCompletionHandler:^(BOOL granted) {
            //
        }];
    }

    [self appLaunchWithCompletionHandler:^(BusinessInjector * _Nullable businessInjector, NSError * _Nullable error) {
        isBusinessInjectorReady = businessInjector != nil;

        if (error) {
            if ([KeychainManager isKeychainLocked]) {
                [NotificationManager showNoAccessToDatabaseNotificationWithCompletionHandler:^{
                    exit(EXIT_SUCCESS);
                }];
            }
            else {
                [ErrorHandler abortWithError:error];
            }
            return;
        }

        if (businessInjector == nil) {
            DDLogError(@"Business services are not ready to use, might start on boarding");
            return;
        }

        [self launchPhase3:businessInjector];        
    }];

    return YES;
}

- (void)launchPhase3:(BusinessInjector *)businessInjector {
    notificationManager = [[NotificationManager alloc] init];
    
    incomingMessageManager = [IncomingMessageManager new];
    
    // Register message processor delegate
    [[ServerConnector sharedServerConnector] registerMessageProcessorDelegate:incomingMessageManager];

    [AppDelegate sharedAppDelegate];
    
    [[KKPasscodeLock sharedLock] setDefaultSettings];
    [[KKPasscodeLock sharedLock] upgradeAccessibility];
    [KKPasscodeLock sharedLock].attemptsAllowed = 10;

    [incomingMessageManager showIsNotPending];

    // apply MDM parameter anyway, perhaps company MDM has changed
    MDMSetup *mdmSetup = [MDMSetup new];
    [mdmSetup loadRenewableValues];

    [TypingIndicatorManager sharedInstance];
    
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    
    if ((state != CallStateIdle && state != CallStateSendOffer && state != CallStateReceivedOffer) | !([[KKPasscodeLock sharedLock] isPasscodeRequired] && isAppLocked)) {
        isAppLocked = NO;
        [self presentApplicationUI];
    } else {
        [self presentPasscodeView];
    }
    
#if DEBUG
    GroupManager *groupManager = [businessInjector groupManagerObjC];
    [groupManager deleteAllSyncRequestRecords];
#endif

    [self.window makeKeyAndVisible];
    
    toaster = [[NewMessageToaster alloc] init];
    
    groupCallUIHelper = [GroupCallUIHelper new];
    [groupCallUIHelper setGlobalGroupCallsManagerSingletonUIDelegate];

    [self checkForInvalidCountryCode];
    
    [IdentityBackupStore syncKeychainWithFile];
    
    [self cleanInbox];
    
    [TipKitManager configureTips];
    
    [launchTaskManager runTasks];
}

#pragma mark - Storyboards

- (UITabBarController *)tabBarController {
    if (_appCoordinator) {
        return _appCoordinator.tabBarController;
    }
    
    return nil;
}

#pragma mark - UI handling

- (void)completedIDSetup {
    [self appLaunchWithCompletionHandler:^(BusinessInjector * _Nullable businessInjector, NSError * _Nullable error) {
        isBusinessInjectorReady = businessInjector != nil;
        
        if (error) {
            if ([KeychainManager isKeychainLocked]) {
                [NotificationManager showNoAccessToDatabaseNotificationWithCompletionHandler:^{
                    exit(EXIT_SUCCESS);
                }];
            }
            else {
                [ErrorHandler abortWithError:error];
            }
            return;
        }
        
        if (businessInjector == nil) {
            DDLogError(@"Business services are not ready to use");
            return;
        }
        
        [self checkHasPrivateChats];
        
        [self launchPhase3:businessInjector];
    }];
}

- (void)checkHasPrivateChats {
   
    EntityManager *entityManager = [[BusinessInjector ui] entityManager];
    NSArray *conversations = [entityManager.entityFetcher conversationEntities];
    BOOL hasPrivate = false;
    
    for (ConversationEntity *conversation in conversations) {
        if (conversation.category.intValue == ConversationCategoryPrivate) {
            hasPrivate = true;
            break;
        }
    }

    if (hasPrivate) {
        [UIAlertTemplate showAlertWithOwner:_window.rootViewController title:[BundleUtil localizedStringForKey:@"privateChat_alert_title"] message: [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"privateChat_setup_alert_message"], TargetManagerObjC.localizedAppName] titleOk:[BundleUtil localizedStringForKey:@"privateChat_code_alert_confirm"] actionOk:^(UIAlertAction * _Nonnull) {
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
    if (UserSettings.sharedUserSettings.ipcCommunicationEnabled == NO) {
        [AppGroup setMeActive];
    }

    [self runWhenBusinessReadyWithTask:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_window makeSecure];

            if ([self isAppInBackground] && isEnteringForeground == false) {
                shouldLoadUIForEnterForeground = true;
            } else {
                if (lastViewController != nil) {
                    if (lockView != nil) {
                        [lockView removeFromSuperview];
                    }
                    self.window.rootViewController = lastViewController;
                    
                    lastViewController = nil;
                    lockView = nil;
                }
                else {
                    _appCoordinator = [[AppCoordinator alloc] initWithWindow:self.window];
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
                
                if (shouldLoadUIForEnterForeground == false) {
                    if ([[WCSessionManager shared] isRunningWCSession] == true){
                        DDLogNotice(@"[Threema Web] presentApplicationUI --> connect all running sessions");
                    }
                    [[WCSessionManager shared] connectAllRunningSessions];
                }
                
                DeviceLinking *deviceLinking = [DeviceLinking new];
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
        });
    }];
}

- (void)handlePresentingScreensWithForce:(BOOL)force {
    // ShouldLoadUIForEnterForeground == false: means UI was never loaded before
    if (shouldLoadUIForEnterForeground == false || force) {
        if (![NavigationBarPromptHandler isCallActiveInBackground]
            && [[VoIPCallStateManager shared] currentCallState] != CallStateIdle)
        {
            UIViewController *viewController = lastViewController.presentedViewController;
            if ([viewController isKindOfClass:[CallViewController class]]
                || self.window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
                });
            }
        } else {
            // Do not perform if we are running screenshots
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
    [self.window makeSecure];
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreateID" bundle:[NSBundle mainBundle] ];
    UIViewController *createIdVC = [storyboard instantiateInitialViewController];
    
    self.window.rootViewController = createIdVC;
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
    if (!TargetManagerObjC.isBusinessApp) {
        return;
    }
    
    EnterLicenseViewController *viewController = [EnterLicenseViewController instantiate];
    
    __block NSString *errorMessage = nil;
    if (notification.object != nil) {
        errorMessage = (NSString *)notification.object;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self closeMainTabBarModalViewsWithCompletion:^{
            [self closeRootViewControllerModalViewsWithCompletion:^{
                [UIView animateWithDuration:0.0 animations:^{
                    if ([AppDelegate isAlertViewShown]) {
                        [self.window.rootViewController dismissViewControllerAnimated:NO completion:^{
                            [self presentEnterLicenseViewController:viewController errorMessage:errorMessage];
                        }];
                    } else {
                        [self presentEnterLicenseViewController:viewController errorMessage:errorMessage];
                    }
                }];
            }];
        }];
    });
}

- (void)presentEnterLicenseViewController:(EnterLicenseViewController *)viewController errorMessage:(NSString *)errorMessage {
    viewController.delegate = self;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    
    if ([self isBusinessInjectorReady]) {
        [[WCSessionManager shared] stopAndForgetAllSessions];
    }
    
    [self.window.rootViewController presentViewController:viewController animated:NO completion:^{
        if (errorMessage != nil) {
            [viewController showErrorMessage:errorMessage];
        }
    }];
}

- (void)showLockScreen {
    // If neither we have a passcode or RS is enabled, we never show a cover. We also cannot show it during setup, since we do not have restoration in place.
    if (!([[KKPasscodeLock sharedLock] isPasscodeRequired] || [AppLaunchManager isRemoteSecretEnabled]) || [self.window.rootViewController isKindOfClass:[SplashViewController class]]) {
        return;
    }
        
    /* Replace the root view controller to ensure it's not visible in snapshots */
    if (![lockView isDescendantOfView:self.window]) {
        if ([self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
            if ([[nav childViewControllers] count] != 0 && ![[[nav childViewControllers] objectAtIndex:0] isKindOfClass:[JKLLockScreenViewController class]]) {
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
        
        UIViewController *privacyViewController = [PrivacyViewController new];
        lockView = privacyViewController.view;
        lockView.frame = self.window.bounds;

        [self.window insertSubview:lockView atIndex:99999];
        [self.window bringSubviewToFront:lockView];
        [self.window snapshotViewAfterScreenUpdates:false];
    } else {
        // This Prevents overriding the current view with a lockscreen, thus ending in an infinite loop
        if ([self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
            if ([[nav childViewControllers] count] != 0 && ![[[nav childViewControllers] objectAtIndex:0] isKindOfClass:[JKLLockScreenViewController class]]) {
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

- (void)setIsWorkContactsLoading:(BOOL)loading {
    isWorkContactsLoading = loading;
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
    [[FileUtility new] deleteAtPath:path error:&error];
}

- (void)cleanInbox {
    // Clean Documents/Inbox directory (old files may accumulate there in case of aborted document share operations),
    // but only if we haven't been opened to share a URL
    if (launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        [self removeDirectoryContents:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Inbox"]];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[FileUtility new] cleanTemporaryDirectoryWithOlderThan:nil];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [CallHistoryManager removeCallsOlderThanChatServerTimeout];
        });
    }
}

- (void)removeDirectoryContents:(NSString*)directory {
    DDLogInfo(@"Remove contents of %@", directory);
    FileUtility *fileUtility = [FileUtility new];
    for (NSString *file in [fileUtility contentsOfDirectoryAtPath:directory error:nil]) {
        [fileUtility deleteAtPath:[directory stringByAppendingPathComponent:file] error:nil];
    }
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
    
    MDMSetup *mdmSetup = [MDMSetup new];
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
    
    [self runWhenBusinessReadyWithTask:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            DDLogNotice(@"AppState: applicationDidEnterBackground executing task");

            [[TypingIndicatorManager sharedInstance] stopObserving];
            [[ThreemaBGTaskManager shared] scheduleTasks];
            
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
            
            // If protected data is not available, then there's no point in starting a background task.
            if (!protectedDataWillBecomeUnavailable) {
                
                BlobManagerObjCWrapper *manager = [[BlobManagerObjCWrapper alloc] init];
                NSString *key = nil;
                int timeout = 0;
                
                if ([[VoIPCallStateManager shared] currentCallState] != CallStateIdle) {
                    // Call is active (the key must be `kAppClosedByUserBackgroundTask` because the app was sent to the background)
                    key = kAppClosedByUserBackgroundTask;
                    timeout = kAppVoIPIncomingCallBackgroundTaskTime;
                }
                else if ([[WCSessionManager shared] isRunningWCSession] == true) {
                    // Web client is active (the key must be `kAppClosedByUserBackgroundTask` because the app was sent to the background)
                    key = kAppClosedByUserBackgroundTask;
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
        });
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    DDLogNotice(@"AppState: applicationWillEnterForeground");
    [DebugLog logAppVersion];

    if (isBusinessInjectorReady == NO) {
        // If the App was removed with passphrase on, is this the only way to unlock
        if ([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
            [self presentPasscodeView];
        }

        return;
    }
    
    [self runWhenBusinessReadyWithTask:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            DDLogNotice(@"AppState: applicationWillEnterForeground executing task");
            [_window makeSecure];
            
            [DebugLog logAppConfiguration];

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
                    if ([lastViewController.presentedViewController isKindOfClass:[CallViewController class]]
                        || self.window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular)
                    {
                        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
                        [self presentApplicationUI];
                        shouldLoadUI = false;
                    }
                    if (self.window.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
                        [[VoIPCallStateManager shared] presentCallViewController];
                        shouldLoadUI = false;
                    }
                }
            }
            
            if (shouldLoadUIForEnterForeground == true && shouldLoadUI == true) {
                [self performSelectorOnMainThread:@selector(presentApplicationUI) withObject:nil waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(updateAllContacts) withObject:nil waitUntilDone:NO];
            }
            else if (TargetManagerObjC.isBusinessApp) {
                // check again for threema safe if a url have changed in mdm
                [self handlePresentingScreensWithForce:YES];
                
                // Check again for screenshot prevention
                if([[MDMSetup new] disableScreenshots]) {
                    [_window makeSecure];
                }
            }
            
            /* ensure we're connected when we enter into foreground */
            if (UserSettings.sharedUserSettings.ipcCommunicationEnabled == NO) {
                [AppGroup setMeActive];
            }

            if ([[WCSessionManager shared] isRunningWCSession] == true){
                DDLogNotice(@"[Threema Web] applicationWillEnterForeground --> connect all running sessions");
            }
            
            [[WCSessionManager shared] connectAllRunningSessions];
            
            DirtyObjectManager *dirtyObjectManager = [BusinessInjector ui].dirtyObjectManagerObjC;
            [dirtyObjectManager refreshDirtyObjectsWithReset:YES];
            
            [[ServerConnector sharedServerConnector] connect:ConnectionInitiatorApp onCompletion:nil];
            [FeatureMask updateLocalObjc];
            [AppDelegate registerForLocalNotifications];
            
            [[TypingIndicatorManager sharedInstance] startObserving];
            [[TypingIndicatorManager sharedInstance] resetTypingIndicators];
            [[NotificationPresenterWrapper shared] dismissAllPresentedNotifications];
            
            if ([[UserSettings sharedUserSettings] enableThreemaGroupCalls]) {
                [[GlobalGroupCallManagerSingleton shared] loadCallsFromDBWithCompletionHandler:^{
                    // Noop
                }];
            }
        });
    }];
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
    DDLogInfo(@"AppState: applicationProtectedDataWillBecomeUnavailable");

    protectedDataWillBecomeUnavailable = YES;

    if (isBusinessInjectorReady == true) {
        if ([[WCSessionManager shared] isRunningWCSession] == false) {
            [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppClosedByUserBackgroundTask];
        }
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
    
    [self runWhenBusinessReadyWithTask:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            DDLogNotice(@"AppState: applicationDidBecomeActive executing task");
            [_window makeSecure];
            
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
            
            if (UserSettings.sharedUserSettings.ipcCommunicationEnabled == NO) {
                [AppGroup setMeActive];
            }

            // set language and mdm description for client version string
            (void)[ThreemaUtility clientVersion];
            
            [Colors resolveTheme];
            [Colors updateWithWindow:_window];
            [[NotificationPresenterWrapper shared] colorChanged];

            [[ServerConnector sharedServerConnector] setIsAppInBackground:[application applicationState] == UIApplicationStateBackground];
            
            [notificationManager updateUnreadMessagesCount];
            
            // Remove notifications from center
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center removeAllDeliveredNotifications];
            
            if (ProcessInfoHelper.isRunningForScreenshots)  {
                NSMutableOrderedSet *workIdentities = [NSMutableOrderedSet new];
                
                if (TargetManagerObjC.isBusinessApp) {
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
        });
    }];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    DDLogNotice(@"AppState: applicationWillTerminate");
    
    // Since we might not disconnect correctly before the app is purged from memory, we make sure to set ourselves inactive.
    [AppGroup setMeInactive];
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window {
    return orientationLock;
}

#pragma mark - Intent handling

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *restorationHandler))restorationHandler {
    return [self continueUserActivity:userActivity];
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

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    
    [self willPresent:notification completion:completionHandler];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    [self didReceiveNotificationResponseWithResponse:response completion:completionHandler];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
    rootToNotificationSettings = true;
    [self openSettingsNotification];
}


#pragma mark - URL & shortcut handling

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [self open: url];
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    [self performActionFor:shortcutItem completion:completionHandler];
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
    [_window makeSecure];
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
    
    if (isAppLocked && isBusinessInjectorReady && !isCallViewControllerPresented) {
        if ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle || [NavigationBarPromptHandler isCallActiveInBackground]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                [self tryTouchIdAuthentication];
            });
        }
    }
}

- (void)dismissPasscodeViewAnimated:(BOOL)animated {
    if (!isAppLocked) {
        return;
    }

    isAppLocked = NO;
    startCheckBiometrics = false;

    // Clear the privacy lock view early so that the async block in
    // applicationDidBecomeActive does not see a stale lockView and
    // redundantly call presentApplicationUI — which would create a
    // brand-new AppCoordinator and destroy the current navigation state.
    if (lockView != nil) {
        [lockView removeFromSuperview];
        lockView = nil;
    }

    [self.window.rootViewController dismissViewControllerAnimated:animated completion:nil];
    
    if (isBusinessInjectorReady == NO) {
        [self appLaunchWithCompletionHandler:^(BusinessInjector * _Nullable businessInjector, NSError * _Nullable error) {
            isBusinessInjectorReady = businessInjector != nil;
        }];

        return;
    }
    
    [self completeAuthentication];
}

- (void)completeAuthentication {
    [self presentApplicationUI];
    
    [self runWhenBusinessReadyWithTask:^{
        URLHandler *urlHandler = [URLHandler new];
        if (pendingUrl) {
            [urlHandler handle:pendingUrl hideAppChooser:NO];
            pendingUrl = nil;
        } else if (pendingShortCutItem) {
            (void)[urlHandler handleWithItem:pendingShortCutItem];
            pendingShortCutItem = nil;
        }
        
        if (evaluatedPolicyDomainState != nil) {
            [[UserSettings sharedUserSettings] setEvaluatedPolicyDomainStateApp:evaluatedPolicyDomainState];
            evaluatedPolicyDomainState = nil;
        }
        
        if (rootToNotificationSettings) {
            [UIApplication.sharedApplication.windows.firstObject.rootViewController dismissViewControllerAnimated:false completion:nil];
            
            [_appCoordinator showNotificationSettings];
            
            rootToNotificationSettings = nil;
        }
    }];
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
                    [UIAlertTemplate showAlertWithOwner:_window.rootViewController title:title message:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"alert_biometrics_changed_message"], TargetManagerObjC.appName, TargetManagerObjC.appName] actionOk:^(UIAlertAction * _Nonnull) {
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
    if (isBusinessInjectorReady == NO) {
        [self appLaunchWithCompletionHandler:^(BusinessInjector * _Nullable businessInjector, NSError * _Nullable error) {
            isBusinessInjectorReady = businessInjector != nil;
        }];
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
                __weak typeof(self) weakSelf = self;
                [DeleteRevokeIdentityManager deleteLocalDataWithoutBusinessReadyObjCWithCompletion:^{
                    weakSelf.window.rootViewController = [SwiftUIAdapter createDeleteSummaryViewOnDismiss:^{
                        // NOOP as we've removed all of the views
                    }];
                }];
            }];
        }];
    }];
}

- (void)closeMainTabBarModalViewsWithCompletion:(nonnull void (^)(void))completion {
    if (_appCoordinator.presentedViewController != nil) {
        [_appCoordinator dismissModalWithAnimated:NO completion:completion];
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
    [_appCoordinator reset];
}

#pragma mark - EnterLicenseDelegate

- (void)licenseConfirmed {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
        [[ServerConnector sharedServerConnector] setIsAppInBackground:[self isAppInBackground]];
        [[ServerConnector sharedServerConnector] connect:ConnectionInitiatorApp onCompletion:nil];
    }];
}

#pragma mark - Accessibility

- (BOOL)accessibilityPerformMagicTap {
    return [self.magicTapHandler handleMagicTap];
}


#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    if (type == PKPushTypeVoIP) {
        // Remove VoIP push token (since min OS version is iOS 15 or above)
        [[ServerConnector sharedServerConnector] removeVoIPPushToken];
    }
    
    if([credentials.token length] == 0) {
        DDLogNotice(@"Token is null");
        return;
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(nonnull PKPushType)type withCompletionHandler:(nonnull void (^)(void))completion {
    if (UserSettings.sharedUserSettings.ipcCommunicationEnabled == NO) {
        [AppGroup setMeActive];
    }

    [self handlePushWithPayload:payload completion:completion];
}

@end
