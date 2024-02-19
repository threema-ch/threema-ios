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

#import "MainTabBarController.h"
#import "AppDelegate.h"
#import "UIDefines.h"

#import "ContactsViewController.h"

#import "ModalNavigationController.h"
#import "PortraitNavigationController.h"

#import "MWPhotoBrowser.h"

#import "AppGroup.h"
#import "AvatarMaker.h"
#import "JKLLockScreenViewController.h"

#import "PreviewImageViewController.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface MainTabBarController () <ModalNavigationControllerDelegate>

@property SingleDetailsViewController *singleDetailViewController;
@property GroupDetailsViewController *groupDetailViewController;

@property ContactsViewController *contactsViewController;
@property ConversationsViewController *conversationsViewController;
@property ArchivedConversationsViewController *archivedConversationsViewController;

@property PortraitNavigationController *contactsNavigationController;
@property PortraitNavigationController *conversationsNavigationController;

@property UIViewController *settingsViewController;
@property UIViewController *profileViewController;

/// Covering view to hide private chat
@property UIView *coverView;

@property NSUInteger currentIndex;

@property BOOL isFirstAppearance;
@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _isFirstAppearance = YES;
    _currentIndex = -1;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedContact:) name:kNotificationShowContact object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedGroup:) name:kNotificationShowGroup object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectedConversation:) name:kNotificationShowConversation object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deletedConversation:) name:kNotificationDeletedConversation object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deletedContact:) name:kNotificationDeletedContact object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSafeSetup:) name:kSafeSetupUI object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    
    [Colors updateWithTabBar:self.tabBar];
    
    _coverView = [[UIView alloc] init];
    _coverView.backgroundColor = [Colors backgroundView];
    _coverView.frame = self.view.bounds;
    _coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self setupSwiftUITabs];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_isFirstAppearance) {
        self.selectedIndex = kDefaultInitialTabIndex;
        _isFirstAppearance = NO;
        
        // We check for modals to be shown
        [LaunchModalManager.shared checkLaunchModals];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _singleDetailViewController = nil;
    _groupDetailViewController = nil;
    
    _contactsViewController = nil;
    
    _conversationsViewController = nil;
    
    _contactsNavigationController = nil;
    _conversationsNavigationController = nil;
    
    _settingsViewController = nil;
    _profileViewController = nil;
}

- (BOOL)shouldAutorotate {
    if ([self.presentedViewController isKindOfClass:[PortraitNavigationController class]]) {
        return NO;
    }
    return YES;
}

-(void)setupSwiftUITabs {
    NSMutableArray *vcs = [[NSMutableArray alloc]initWithArray:self.viewControllers];
    _settingsViewController = SwiftUIAdapter.createSettingsView;
    _profileViewController = SwiftUIAdapter.createProfileView;
    [vcs addObject:_profileViewController];
    [vcs addObject:_settingsViewController];
    [self setViewControllers:vcs animated:NO];
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([self.presentedViewController isKindOfClass:[PortraitNavigationController class]]) {
        return NO;
    }
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    NSUInteger index = [self.viewControllers indexOfObject:(UIViewController * _Nonnull)selectedViewController];
    [self setSelectedIndex:index];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    // fallback for when setting share extension inactive fails for some reason (crash etc.)
    [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
    [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
    
    if (SYSTEM_IS_IPAD == NO) {
        [super setSelectedIndex:selectedIndex];
        return;
    }
    
    NSUInteger previousIndex = _currentIndex;
    _currentIndex = selectedIndex;
    
    switch (selectedIndex) {
        case kChatTabBarIndex:
            if (selectedIndex != previousIndex) {
                [self switchToChats];
            }
            break;
            
        case kContactsTabBarIndex:
            if (selectedIndex != previousIndex) {
                [self switchToContacts];
            }
            break;
            
        case kMyIdentityTabBarIndex:
            [self showMyIdentity];
            break;
            
        case kSettingsTabBarIndex:
            [self showSettings];
            break;
            
        default:
            // ignore
            break;
    }
    
    _currentIndex = selectedIndex;
}

- (void)switchToChats {
    if (_conversationsViewController == nil) {
        _conversationsViewController = (ConversationsViewController *)[self loadViewControllerNamed:@"conversationsViewController"];
        _conversationsNavigationController = [[PortraitNavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
        [_conversationsNavigationController setViewControllers:@[_conversationsViewController]];
    }
    
    self.splitViewController.viewControllers = @[
        _conversationsNavigationController,
        self
    ];
    [self switchConversation:nil notification:nil];
}

- (void)switchToContacts {
    if (_contactsViewController == nil) {
        _contactsViewController = (ContactsViewController *)[self loadViewControllerNamed:@"contactsViewController"];
        _contactsNavigationController = [[PortraitNavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
        [_contactsNavigationController setViewControllers:@[_contactsViewController]];
    }
    
    self.splitViewController.viewControllers = @[
        _contactsNavigationController,
        self
    ];
    [self switchContact];
}

- (void)switchConversation:(Conversation *)conversation notification:(NSNotification *) notification{
    
    // New ChatView iPad
    ChatViewController *chatViewController = nil;
    Conversation *conv = conversation;
    if (conversation == nil) {
        conv = _conversationsViewController.selectedConversation ? _conversationsViewController.selectedConversation : [_conversationsViewController getFirstConversation];
    }
    
    if (conv) {
        ShowConversationInformation* info = [ShowConversationInformation createInfoFor:notification];
        chatViewController = [[ChatViewController alloc]initWithConversation: conv showConversationInformation: info];
    }
    
    if (chatViewController && conv.willBeDeleted == NO) {
        if ([chatViewController conversation].conversationCategory == ConversationCategoryPrivate && !AppDelegate.sharedAppDelegate.isAppLocked){
            [self presentPasscodeView];
            
        } else {
            [self removeCoverView];
            UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
            [navigationController setViewControllers:@[chatViewController]];
            [_conversationsViewController setSelectionFor: chatViewController.conversation];
            
            if ([_conversationsNavigationController.topViewController isKindOfClass:[ArchivedConversationsViewController class]]) {
                [_conversationsViewController removeSelectedConversation];
            }
        }
        
    } else {
        [self clearNavigationControllerAt:kChatTabBarIndex];
    }
    [super setSelectedIndex:kChatTabBarIndex];
}

- (void)switchContact {
    if (_singleDetailViewController) {
        UINavigationController *navigationController = self.viewControllers[kContactsTabBarIndex];
        [navigationController setViewControllers:@[_singleDetailViewController]];
        
        if ([_contactsViewController isWorkActive]) {
            [_contactsViewController setSelectionForWorkContact:_singleDetailViewController._contact];
        } else {
            [_contactsViewController setSelectionForContact:_singleDetailViewController._contact];
        }
    } else if (_groupDetailViewController) {
        UINavigationController *navigationController = self.viewControllers[kContactsTabBarIndex];
        [navigationController setViewControllers:@[_groupDetailViewController]];
        
        [_contactsViewController setSelectionForGroup:_groupDetailViewController._group];
    } else {
        BOOL gotDetailsView = [_contactsViewController showFirstEntryForCurrentMode];
        if (gotDetailsView == NO) {
            [self clearNavigationControllerAt:kContactsTabBarIndex];
        }
    }
    
    [super setSelectedIndex:kContactsTabBarIndex];
}

- (void)showMyIdentity {
    [self showModal: SwiftUIAdapter.createProfileView];
    return;
}

- (void)showSettings {
    [self showModal: SwiftUIAdapter.createSettingsView];
}

- (void)clearNavigationControllerAt:(NSUInteger)index {
    UINavigationController *navigationController = self.viewControllers[index];
    UIViewController *dummyViewController = [[UIViewController alloc] init];
    [navigationController setViewControllers:@[dummyViewController]];
}

- (UIViewController *)loadViewControllerNamed:(NSString *)viewControllerName {
    UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
    return [storyboard instantiateViewControllerWithIdentifier:viewControllerName];
}

- (UIViewController *)loadSettingsControllerNamed:(NSString *)viewControllerName {
    return SwiftUIAdapter.createProfileView;
}

- (UIViewController *)loadMyIdentityController {
    return SwiftUIAdapter.createProfileView;
}

- (void)showModal:(UIViewController *)viewController {
    ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
    navigationController.showDoneButton = YES;
    navigationController.dismissOnTapOutside = YES;
    navigationController.modalDelegate = self;
    
    [navigationController pushViewController:viewController animated:NO];
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)applicationDidReceiveMemoryWarning:(NSNotification*)notification {
    _conversationsViewController = nil;
    _conversationsNavigationController = nil;
}

- (BOOL)isChatTopViewController {
    if ([_conversationsNavigationController.topViewController isKindOfClass:[ChatViewController class]]) {
        return true;
    }
    return false;
}

#pragma mark - notifications

- (void)selectedGroup:(NSNotification*)notification {
    Group *group = [notification.userInfo objectForKey:kKeyGroup];
    
    _singleDetailViewController = nil;
    
    if (SYSTEM_IS_IPAD) {
        _groupDetailViewController = [[GroupDetailsViewController alloc] initFor:group displayMode:GroupDetailsDisplayModeDefault displayStyle:DetailsDisplayStyleDefault delegate:nil];
        
        if (self.selectedIndex == kContactsTabBarIndex) {
            [self switchContact];
        } else {
            [self setSelectedIndex:kContactsTabBarIndex];
        }
    } else {
        if (_contactsViewController == nil) {
            _contactsNavigationController = self.viewControllers[kContactsTabBarIndex];
            _contactsViewController = [[_contactsNavigationController viewControllers] objectAtIndex:0];
        }
        
        [self setSelectedViewController:_contactsNavigationController];
        [_contactsNavigationController popToViewController:_contactsViewController animated:NO];
        [_contactsViewController showDetailsForGroup:group];
    }
}

- (void)selectedContact:(NSNotification*)notification {
    
    if (notification.userInfo[@"fromURL"] == nil && self.selectedIndex == kChatTabBarIndex) {
        // This means we don't come from an URL and we scanned an ID from the chat-details and we don't want to change tabs
        return;
    }
    
    ContactEntity *contact = [notification.userInfo objectForKey:kKeyContact];
    
    _groupDetailViewController = nil;
    
    if (SYSTEM_IS_IPAD) {
        [self hideModal];
        
        _singleDetailViewController = [[SingleDetailsViewController alloc] initFor:contact displayStyle:DetailsDisplayStyleDefault];
        
        if (self.selectedIndex == kContactsTabBarIndex) {
            [self switchContact];
        } else {
            [self setSelectedIndex:kContactsTabBarIndex];
        }
    } else {
        // Only show contact details non-modally if we're already in the Contacts tab
        if (self.selectedIndex == kContactsTabBarIndex) {
            // Switch to contact's details if we're already in the contacts tab
            if (_contactsViewController == nil) {
                _contactsNavigationController = self.viewControllers[kContactsTabBarIndex];
                _contactsViewController = [[_contactsNavigationController viewControllers] objectAtIndex:0];
            }
            
            if ([[[_contactsNavigationController viewControllers] lastObject] isKindOfClass:[SingleDetailsViewController class]]) {
                SingleDetailsViewController *currentContact = (SingleDetailsViewController *)[[_contactsNavigationController viewControllers] lastObject];
                if ([currentContact._contact.identity isEqualToString:contact.identity]) {
                    return;
                }
            }
            
            [self setSelectedViewController:_contactsNavigationController];
            [_contactsNavigationController popToViewController:_contactsViewController animated:NO];
            [_contactsViewController showDetailsForContact:contact];
            
        } else {
            // Show contact details modally
            SingleDetailsViewController *singleDetailsViewController = [[SingleDetailsViewController alloc] initFor:contact displayStyle:DetailsDisplayStyleDefault];
            ThemedNavigationController *themedNavigationController = [[ThemedNavigationController alloc] initWithRootViewController:singleDetailsViewController];
            [self presentViewController:themedNavigationController animated:YES completion:nil];
        }
    }
}

-(void)showNotificationSettings {
    UIViewController *notificationViewController = [SwiftUIAdapter createNotificationSettingsView];
    
    if(SYSTEM_IS_IPAD) {
        UIViewController *settings = _settingsViewController;
        ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
        navigationController.showDoneButton = YES;
        navigationController.dismissOnTapOutside = YES;
        navigationController.modalDelegate = self;
        
        [navigationController pushViewController:settings animated:NO];
        [navigationController pushViewController:notificationViewController animated:NO];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    else {
        [self setSelectedIndex:kSettingsTabBarIndex];
        [[NSNotificationCenter defaultCenter] postNotificationName:kShowNotificationSettings object:nil userInfo:nil];
    }
}

- (void)showSafeSetup:(NSNotification*)notification {
    [self showThreemaSafe];
}

-(void)showThreemaSafe {
    UIViewController *notificationViewController = [SwiftUIAdapter createProfileView];
    
    if(SYSTEM_IS_IPAD) {
        UIViewController *profile = _profileViewController;
        ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
        navigationController.showDoneButton = YES;
        navigationController.dismissOnTapOutside = YES;
        navigationController.modalDelegate = self;
        
        [navigationController pushViewController:profile animated:NO];
        [navigationController pushViewController:notificationViewController animated:NO];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    else {
        [self setSelectedIndex:kMyIdentityTabBarIndex];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowSafeSetup object:nil userInfo:nil];
    }
}

- (void)selectedConversation:(NSNotification*)notification {
    [self hideModal];
        
    if (SYSTEM_IS_IPAD) {
        if (self.selectedIndex == kChatTabBarIndex) {
            Conversation *conv = [self getConversationForNotificationInfo:notification.userInfo];
            [self switchConversation: conv notification:notification];
        } else {
            [self setSelectedIndex:kChatTabBarIndex];
            Conversation *conv = [self getConversationForNotificationInfo:notification.userInfo];
            [self switchConversation: conv notification:notification];
        }
    } else {
        // New ChatView iPhone
        if (_conversationsViewController == nil) {
            _conversationsNavigationController = self.viewControllers[kChatTabBarIndex];
        }
        Conversation *conv = [self getConversationForNotificationInfo:notification.userInfo];
        if (conv == nil) {
            DDLogError(@"Unable to show chat because conversation is nil");
            return;
        }
        ShowConversationInformation *info = [ShowConversationInformation createInfoFor:notification];

        ChatViewController *chatViewController = [[ChatViewController alloc]initWithConversation:conv showConversationInformation:info];
        
        if ([_conversationsNavigationController.topViewController isKindOfClass:[ArchivedConversationsViewController class]]) {
            _archivedConversationsViewController = (ArchivedConversationsViewController *) _conversationsNavigationController.topViewController;
            [_archivedConversationsViewController displayChatWithChatViewController: chatViewController animated:YES];
            [self setSelectedViewController:_conversationsNavigationController];
            
        } else if ([_conversationsNavigationController.topViewController isKindOfClass:[ConversationsViewController class]]) {
            _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
            [_conversationsViewController displayChatWithChatViewController: chatViewController animated:YES];
            [self setSelectedViewController:_conversationsNavigationController];
        }
        else {
            // Check if open chat is same we want to open
            if ([_conversationsNavigationController.topViewController isKindOfClass:[ChatViewController class]]) {
                ChatViewController * topChatViewController = (ChatViewController *) _conversationsNavigationController.topViewController;
                if (topChatViewController.conversation == chatViewController.conversation && notification == nil) {
                    return;
                }
            }
            
            [_conversationsNavigationController popToRootViewControllerAnimated:NO];
            // There is a race condition during pop, so we need to check again.
            if ([_conversationsNavigationController.topViewController isKindOfClass:[ConversationsViewController class]]) {
                _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
                [_conversationsViewController displayChatWithChatViewController: chatViewController animated:YES];
                [self setSelectedViewController:_conversationsNavigationController];
            }
        }
    }
}

- (void)deletedConversation:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        Conversation *deletedConversation = notification.userInfo[kKeyConversation];
        Conversation *selectedConversation = [_conversationsViewController selectedConversation];
        if (selectedConversation == deletedConversation) {
            if (self.selectedIndex == kChatTabBarIndex) {
                [self switchConversation: nil notification:notification];
            }
        }
        
        if (_groupDetailViewController._group.conversation == deletedConversation) {
            _groupDetailViewController = nil;
            if (self.selectedIndex == kContactsTabBarIndex) {
                [self switchContact];
            }
        }
    }
}

- (Conversation *)getConversationForNotificationInfo:(NSDictionary *)info {
    __block Conversation *conversation = [info objectForKey:kKeyConversation];
    __block ContactEntity *notificationContact = [info objectForKey:kKeyContact];
    if (conversation == nil) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            ContactEntity *contact = (ContactEntity *)[entityManager.entityFetcher getManagedObjectById:notificationContact.objectID];
            if (contact) {
                conversation = [entityManager conversationForContact:contact createIfNotExisting:YES];
            }
        }];
    }
    
    return conversation;
}

- (void)deletedContact:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        ContactEntity *deletedContact = [notification.userInfo objectForKey:kKeyContact];
        if (_singleDetailViewController._contact == deletedContact) {
            _singleDetailViewController = nil;
            if (self.selectedIndex == kContactsTabBarIndex) {
                [self switchContact];
            }
        }
        
        UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
        ChatViewController *chatViewController = navigationController.viewControllers.firstObject;
        if ([chatViewController isKindOfClass:[ChatViewController class]]) {
            if (chatViewController.conversation.willBeDeleted) {
                _conversationsViewController.selectedConversation = nil;
                [self switchConversation:nil notification:nil];
            }
        }
    }
}

- (void)hideModal {
    if (self.presentedViewController == nil) {
        return;
    }
    
    if (_currentIndex == kSettingsTabBarIndex || _currentIndex == kMyIdentityTabBarIndex) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    UIViewController *controller = self.presentedViewController;
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController*)controller;
        if ([navigationController.topViewController isKindOfClass:[MWPhotoBrowser class]]) {
            [navigationController dismissViewControllerAnimated:YES completion:nil];
        }
        else if ([navigationController.topViewController isKindOfClass:[PreviewImageViewController class]]) {
            [navigationController dismissViewControllerAnimated:YES completion:nil];
        }
        else if ([navigationController.topViewController isKindOfClass:[SingleDetailsViewController class]]
                 || [navigationController.topViewController isKindOfClass:[GroupDetailsViewController class]]) {
            [navigationController dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)wallpaperChanged:(NSNotification*)notification {
    DDLogInfo(@"Wallpaper changed, removing cached chat view controllers");
    // On iPad the wallpaper for an open chat only changes when the settings are dismissed if we don't call this
    // On iPhone there is no way to change the wallpaper without leaving the chat
    [self resetDisplayedChat];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    DDLogInfo(@"Color theme changed, removing cached chat view controllers");
    
    [AvatarMaker clearCache];
    [Colors updateWithWindow:[[AppDelegate sharedAppDelegate] window]];
    [Colors updateWithNavigationBar:self.selectedViewController.navigationController.navigationBar];
    [Colors updateWithTabBar:self.tabBar];
        
    [self setNeedsStatusBarAppearanceUpdate];
    
    if (SYSTEM_IS_IPAD) {
        [_singleDetailViewController refresh];
        [Colors updateWithNavigationBar:_singleDetailViewController.navigationController.navigationBar];
        [_contactsViewController refresh];
        [Colors updateWithNavigationBar:_contactsViewController.navigationController.navigationBar];
        
        [_conversationsViewController refresh];
        [Colors updateWithNavigationBar:_conversationsViewController.navigationController.navigationBar];
                
        for (UIViewController *vc in _conversationsNavigationController.viewControllers) {
            [Colors updateWithNavigationBar:vc.navigationController.navigationBar];
        }
        
        [Colors updateWithNavigationBar:_conversationsNavigationController.navigationBar];
    }
}

- (void)resetDisplayedChat {
    if (SYSTEM_IS_IPAD) {
        Conversation *selectedConversation = [_conversationsViewController selectedConversation];
        [self switchConversation:selectedConversation notification:nil];
    } else {
        if (self.selectedIndex == kChatTabBarIndex) {
            [_conversationsNavigationController popToRootViewControllerAnimated:true];
        }
    }
}

#pragma mark - ModalNavigationControllerDelegate

- (void)didDismissModalNavigationController {
    //fool the tab bar to switch the selected tab
    NSUInteger index = [self.viewControllers indexOfObject:self.selectedViewController];
    [self setSelectedIndex:index];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([[UserSettings sharedUserSettings] useSystemTheme] && [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                if (Colors.theme != ThemeDark) {
                    [Colors setTheme:ThemeDark];
                }
            } else {
                if (Colors.theme != ThemeLight) {
                    [Colors setTheme:ThemeLight];
                }
            }
        }
    }
}


# pragma mark - JKLLockscreen Delegate
// Used for private chats on iPad
- (void) presentPasscodeView{
    
    // If we restored from safe and no password is set, we inform the user that he needs to set one and present them the set password screen
    if(![[KKPasscodeLock sharedLock] isPasscodeRequired]) {
        [self presentPasscodeViewWithUserInfoAlert];
        return;
    }
    
    JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
    vc.dataSource = self;
    vc.delegate = self;
    vc.lockScreenMode = LockScreenModeExtension;

    [self.viewControllers[kChatTabBarIndex].view addSubview: _coverView];
    
    ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
    navigationController.showFullScreenOnIPad = NO;
    navigationController.showDoneButton = NO;
    navigationController.navigationBar.hidden = YES;
    navigationController.dismissOnTapOutside = NO;
    navigationController.modalDelegate = self;
    
    [navigationController pushViewController:vc animated:NO];
    [self.viewControllers[kChatTabBarIndex] presentViewController:navigationController animated:NO completion:nil];
    
}

- (void) presentPasscodeViewWithUserInfoAlert{
    JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
    vc.dataSource = self;
    vc.delegate = self;
    vc.lockScreenMode = LockScreenModeNew;

    [UIAlertTemplate showAlertWithOwner:self.viewControllers[kChatTabBarIndex] title:[BundleUtil localizedStringForKey:@"privateChat_alert_title"] message:[BundleUtil localizedStringForKey:@"privateChat_setup_alert_message"] titleOk:[BundleUtil localizedStringForKey:@"privateChat_code_alert_confirm"] actionOk:^(UIAlertAction * _Nonnull action) {
        
        [self.viewControllers[kChatTabBarIndex].view addSubview: _coverView];
        
        ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
        navigationController.showFullScreenOnIPad = NO;
        navigationController.showDoneButton = NO;
        navigationController.navigationBar.hidden = YES;
        navigationController.dismissOnTapOutside = NO;
        navigationController.modalDelegate = self;
        
        [navigationController pushViewController:vc animated:NO];
        [self.viewControllers[kChatTabBarIndex] presentViewController:navigationController animated:NO completion:nil];
    } titleCancel:nil actionCancel:^(UIAlertAction * _Nonnull action) {
        return;
    }];
}

- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController *)viewController{
    [self removeCoverView];
    UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
    
    if ([_conversationsNavigationController.topViewController isKindOfClass:[ConversationsViewController class]]
        && _conversationsViewController != nil
        && _conversationsViewController.selectedConversation != nil) {
        Conversation *conversation = _conversationsViewController.selectedConversation;
        ChatViewController *chatViewController = [[ChatViewController alloc]initWithConversation: conversation showConversationInformation:nil];
        [navigationController setViewControllers:@[chatViewController]];
    }
    else {
        Conversation *conversation = [_conversationsViewController getFirstConversation];
        ChatViewController *chatViewController = [[ChatViewController alloc]initWithConversation: conversation showConversationInformation:nil];
        [navigationController setViewControllers:@[chatViewController]];
        [_conversationsViewController setSelectionFor: conversation];
    }
    
    if ([_conversationsNavigationController.topViewController isKindOfClass:[ArchivedConversationsViewController class]]) {
        [_conversationsViewController removeSelectedConversation];
    }
}

- (void)shouldEraseApplicationData:(JKLLockScreenViewController *)viewController{
    [[AppDelegate sharedAppDelegate] eraseApplicationData:viewController];
}

- (BOOL)allowTouchIDLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController{
    return [KKPasscodeLock sharedLock].isTouchIdOn;
}

-(void)removeCoverView {
    [self.coverView removeFromSuperview];
}


@end
