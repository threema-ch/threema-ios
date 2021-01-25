//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "RootNavigationController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <ThreemaFramework/ThreemaFramework-Swift.h>

#import "ContactGroupPickerViewController.h"
#import "Contact.h"
#import "GroupProxy.h"
#import "ServerConnector.h"
#import "DatabaseManager.h"
#import "MyIdentityStore.h"
#import "BundleUtil.h"
#import "KKPasscodeLock.h"
#import "TouchIdAuthentication.h"
#import "NibUtil.h"
#import "RectUtil.h"
#import "ProgressViewController.h"
#import "AppGroup.h"
#import "MessageQueue.h"
#import "UserSettings.h"
#import "ModalNavigationController.h"
#import "UTIConverter.h"
#import "Utils.h"
#import "FeatureMask.h"
#import "LicenseStore.h"
#import "JKLLockScreenViewController.h"
#import "DocumentManager.h"
#import "SenderItemManager.h"

#define MAX_NUM_PASSCODE_TRIES 3

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface RootNavigationController () <ContactGroupPickerDelegate, KKPasscodeViewControllerDelegate, JKLLockScreenViewControllerDelegate, ProgressViewDelegate, ModalNavigationControllerDelegate, SenderItemDelegate>

@property NSMutableSet *recipientConversations;

@property SenderItemManager *itemManager;

@property NSInteger passcodeTryCount;
@property JKLLockScreenViewController *passcodeVC;

@property ProgressViewController *progressViewController;

@property BOOL isAuthorized;

@end

@implementation RootNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _passcodeTryCount = 0;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [AppGroup setGroupId:THREEMA_GROUP_IDENTIFIER];
        [AppGroup setAppId:APP_ID];
        
        // Initialize app setup state (checking database file exists) as early as possible
        (void)[[AppSetupState alloc] init];
    });
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [Colors updateNavigationBar:self.navigationBar];
    
    // drop shared instance in order to adapt to user's configuration changes
    [UserSettings resetSharedInstance];

    [AppGroup setActive:YES forType:AppGroupTypeShareExtension];
    
#ifdef DEBUG
    [LogManager initializeGlobalLoggerWithDebug:YES];
#else
    [LogManager initializeGlobalLoggerWithDebug:NO];
#endif

    if ([self extensionIsReady]) {
        [self presentSharingUI];
    } else {
        ;//nop
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadItemsFromContext];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)presentSharingUI {
    // Add received pushs into db
    [[ServerConnector sharedServerConnector] connect];
    
    ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
    navigationController.navigationBar.translucent = NO;
    [self presentViewController:navigationController animated:YES completion:^{
        //nop
    }];
}

- (BOOL)isDBReady {
    DatabaseManager *dbManager = [DatabaseManager dbManager];
    if ([dbManager storeRequiresMigration]) {
        [self showNeedStartAppFirst];
        return NO;
    }
    
    return YES;
}

- (BOOL)hasLicense {
    if ([[LicenseStore sharedLicenseStore] isValid] == NO) {
        [self showNeedStartAppFirst];
        return NO;
    }
    
    return YES;
}

- (void)showNeedStartAppFirst {
    NSString *title = NSLocalizedString(@"need_to_start_app_first_title", nil);
    NSString *message = NSLocalizedString(@"need_to_start_app_first_message", nil);
    [self showAlertWithTitle:title message:message closeOnOk:YES];
}

- (BOOL)checkPasscode {
    NSUserDefaults *defaults = [AppGroup userDefaults];
    time_t openTime = [defaults doubleForKey:@"UIActivityViewControllerOpenTime"];
    BOOL hidePasslock = NO;
    int maxTimeSinceApp = 10;
    time_t uptime = [Utils systemUptime];
    if (uptime > 0 && openTime > 0 && (uptime - openTime) > 0 && (uptime - openTime) < maxTimeSinceApp) {
        hidePasslock = YES;
    }
    
    [defaults removeObjectForKey:@"UIActivityViewControllerOpenTime"];
    
    if (([[KKPasscodeLock sharedLock] isPasscodeRequired] && [[KKPasscodeLock sharedLock] isWithinGracePeriod] == NO) && !hidePasslock) {
        _isAuthorized = NO;
        
        JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
        vc.lockScreenMode = LockScreenModeExtension;
        vc.delegate = self;
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBarHidden = YES;
        [self presentViewController:nav animated:YES completion:^{
            [self tryTouchIdAuthentication];
        }];
        
        return NO;
    }
    
    return YES;
}

- (void)tryTouchIdAuthentication {
    [TouchIdAuthentication tryTouchIdAuthenticationCallback:^(BOOL success, NSError *error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.presentedViewController dismissViewControllerAnimated:YES completion:^{
                    [self presentSharingUI];
                }];
            });
        }
    }];
}

- (BOOL)checkContextItems {
    if ([self.extensionContext.inputItems count] == 0) {
        NSString *title = NSLocalizedString(@"error_message_no_items_title", nil);
        NSString *message = NSLocalizedString(@"error_message_no_items_message", nil);
        [self showAlertWithTitle:title message:message closeOnOk:YES];
        
        return NO;
    }
    
    return YES;
}

- (BOOL)extensionIsReady {
    
    // drop shared instance, otherwise we won't notice any changes to it
    [MyIdentityStore resetSharedInstance];
    AppSetupState *appSetupSate = [[AppSetupState alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore]];
    if (![appSetupSate isAppSetupCompleted]) {
        [self showNeedStartAppFirst];
        return NO;
    }

    if ([self hasLicense] == NO) {
        return NO;
    }
    
    if ([self isDBReady] == NO) {
        return NO;
    }
    
    if ([self checkPasscode] == NO) {
        return NO;
    }
    
    if ([self checkContextItems] == NO) {
        return NO;
    }
    
    return YES;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message closeOnOk:(BOOL)closeOnOk {
    [UIAlertTemplate showAlertWithOwner:self.presentedViewController title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
        if (closeOnOk) {
            [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
                [self commonCompletionHandler];
            }];
        }
    }];
}

- (void)showAlert:(UIAlertController *)alertController {
    if (self.presentedViewController) {
        [self.presentedViewController presentViewController:alertController animated:YES completion:nil];
    } else {
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)loadItemsFromContext {
    _itemManager = [[SenderItemManager alloc] init];
    _itemManager.delegate = self;
    
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            NSString *baseUTI = [self getBaseUTIType:itemProvider];
            NSString *secondUTI = [self getSecondUTIType:itemProvider];
            [_itemManager addItem:itemProvider forType:baseUTI secondType:secondUTI];
        }
    }
}

- (NSString *)getBaseUTIType:(NSItemProvider *)itemProvider {
    NSMutableArray *typeIdentifiers = [NSMutableArray arrayWithArray:itemProvider.registeredTypeIdentifiers];
    
    if (@available(iOS 13.0, *)) {
        if ([typeIdentifiers count] >= 1) {
            return [typeIdentifiers lastObject];
        }
        return UTTYPE_FILE_URL;
    } else {
        if ([itemProvider hasItemConformingToTypeIdentifier:UTTYPE_FILE_URL]) {
            [typeIdentifiers removeObject:UTTYPE_FILE_URL];
        }
        
        // take the first type
        if ([typeIdentifiers count] >= 1) {
            return [typeIdentifiers firstObject];
        }
        
        return UTTYPE_FILE_URL;
    }
}

- (NSString *)getSecondUTIType:(NSItemProvider *)itemProvider {
    NSMutableArray *typeIdentifiers = [NSMutableArray arrayWithArray:itemProvider.registeredTypeIdentifiers];
    
    if (@available(iOS 13.0, *)) {
        if ([itemProvider hasItemConformingToTypeIdentifier:UTTYPE_FILE_URL]) {
            [typeIdentifiers removeObject:UTTYPE_FILE_URL];
        }
        if ([typeIdentifiers count] >= 1) {
            return [typeIdentifiers firstObject];
        }
        return UTTYPE_FILE_URL;
    } else {
        return nil;
    }
}

- (BOOL)canConnect {
    return [ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn;
}

- (void)showProgressUI {
    _progressViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ProgressViewController"];
    _progressViewController.delegate = self;
    _progressViewController.totalCount = _itemManager.itemCount * [_recipientConversations count];
    
    self.presentedViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    _progressViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    if ([self.presentedViewController isKindOfClass:[ModalNavigationController class]]) {
        ((ModalNavigationController *)self.presentedViewController).modalDelegate = nil;
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        [self presentViewController:_progressViewController animated:YES completion:^{
            [self sendItems];
        }];
    }];
}

- (void)recipientConversationsRemoveContacts:(NSArray *)contacts {
    NSMutableSet *newRecipientConversations = [NSMutableSet setWithSet:_recipientConversations];
    for (Contact *contact in contacts) {
        for (Conversation *conversation in _recipientConversations) {
            if (conversation.isGroup) {
                if ([conversation.members isEqualToSet:[NSSet setWithArray:contacts]]) {
                    [newRecipientConversations removeObject:conversation];
                }
            } else if (conversation.contact == contact) {
                [newRecipientConversations removeObject:conversation];
            }
        }
    }
    
    _recipientConversations = newRecipientConversations;
}

- (void)sendItems {
    [_itemManager sendItemsTo:_recipientConversations];
}

- (void)startSending {
    NSInteger count = [_recipientConversations count] * _itemManager.itemCount;
    
    if (count == 0) {
        if (_itemManager.itemCount == 0) {
            // exit only if no items to send, otherwise the user has the chance to select another recipient
            [self finishAndClose];
        }
        return;
    }
    
    if ([self canConnect] == NO) {
        NSString *title = NSLocalizedString(@"cannot_connect_title", nil);
        NSString *message = NSLocalizedString(@"cannot_connect_message", nil);
        [self showAlertWithTitle:title message:message closeOnOk:NO];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressUI];
    });
}

- (void)commonCompletionHandler {
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
}

- (void)completionHandler:(BOOL)expired {
    [self commonCompletionHandler];
    
    if (expired) {
        _itemManager.shouldCancel = YES;
        [[ServerConnector sharedServerConnector] disconnect];
    } else {
        [[ServerConnector sharedServerConnector] disconnectWait];
    }
}

- (void)finishAndClose {
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    [[MessageQueue sharedMessageQueue] save];
    
    NSInteger delay = 0;
    if (_progressViewController != nil) {
        // show progress for long enough & give server connection enough time to handle acks
        delay = 1;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
            [self completionHandler:expired];
        }];
    });
}

#pragma mark - ContactGroupPickerDelegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    _recipientConversations = [NSMutableSet set];
    _itemManager.sendAsFile = sendAsFile;
    
    if (contactPicker.additionalTextToSend) {
        [_itemManager addText:contactPicker.additionalTextToSend];
    }
    
    for (Conversation *conversation in conversations) {
        [_recipientConversations addObject:conversation];
    }
    
    [self startSending];
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [self finishAndClose];
}

#pragma mark - Passcode lock delegate

- (void)shouldEraseApplicationData:(JKLLockScreenViewController *)viewController {
    // do not delete stuff from within extension, just quit
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
        [self commonCompletionHandler];
    }];
}

- (void)didPasscodeEnteredIncorrectly:(JKLLockScreenViewController *)viewController {
    if (_passcodeTryCount >= MAX_NUM_PASSCODE_TRIES) {
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:^(BOOL expired) {
            [self commonCompletionHandler];
        }];
    }
    
    _passcodeTryCount++;
}

- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController *)viewController {
    _isAuthorized = YES;
    
}

- (void)unlockWasCancelledLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController {
    [self finishAndClose];
}

- (void)didPasscodeViewDismiss:(JKLLockScreenViewController *)viewController {
    if (_isAuthorized) {
        [self presentSharingUI];
    }
}


#pragma mark - ProgressViewDelegate

- (void)progressViewDidCancel {
    _itemManager.shouldCancel = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishAndClose];
    });
}

#pragma mark - ModalNavigationControllerDelegate

- (void)willDismissModalNavigationController {
    [self finishAndClose];
}

#pragma mark - SenderItemDelegate

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showAlertWithTitle:title message:message closeOnOk:YES];
    });
}

- (void)finishedItem:(id)item {
    [_progressViewController finishedItem:item];
}

- (void)setProgress:(NSNumber *)progress forItem:(id)item {
    [_progressViewController setProgress:progress forItem:item];
}

- (void)setFinished {
    [self finishAndClose];
}

#pragma mark UIApplicationDelegate

- (void)didBecomeActive:(NSNotification*)notification {
    [AppGroup setActive:YES forType:AppGroupTypeShareExtension];
}

@end
