//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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
#import "StatusNavigationBar.h"

#import "ContactsViewController.h"
#import "Old_ChatViewController.h"

#import "ModalNavigationController.h"
#import "MyIdentityViewController.h"
#import "PortraitNavigationController.h"

#import "Old_ChatViewControllerCache.h"
#import "MWPhotoBrowser.h"

#import "AppGroup.h"
#import "AvatarMaker.h"
#import "JKLLockScreenViewController.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface MainTabBarController () <ModalNavigationControllerDelegate>

@property Old_ChatViewController *old_ChatViewController;
@property SingleDetailsViewController *singleDetailViewController;
@property GroupDetailsViewController *groupDetailViewController;

@property ContactsViewController *contactsViewController;
@property ConversationsViewController *conversationsViewController;
@property ArchivedConversationsViewController *archivedConversationsViewController;

@property PortraitNavigationController *contactsNavigationController;
@property PortraitNavigationController *conversationsNavigationController;

@property UINavigationController *settingsNavigationController;

@property MyIdentityViewController *myIdentityViewController;
@property SettingsViewController *settingsViewController;

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wallpaperChanged:) name:kNotificationWallpaperChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    // TODO: (IOS-2860) Remove next two
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatFontSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voiceOverStatusDidChange) name:UIAccessibilityVoiceOverStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    
    [Colors updateWithTabBar:self.tabBar];
    
    _coverView = [[UIView alloc] init];
    _coverView.backgroundColor = [Colors backgroundView];
    _coverView.frame = self.view.bounds;
    _coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Checks is device linking not finished yet
    if ([[UserSettings sharedUserSettings] blockCommunication]) {
        [self showMultiDeviceWizard];
    }
    
    if (_isFirstAppearance) {
        self.selectedIndex = kDefaultInitialTabIndex;
        _isFirstAppearance = NO;
        
        // We check for modals to be shown
        [LaunchModalManager.shared checkLaunchModals];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    _old_ChatViewController = nil;
    _singleDetailViewController = nil;
    _groupDetailViewController = nil;
    
    _contactsViewController = nil;
    
    _conversationsViewController = nil;
    
    _contactsNavigationController = nil;
    _conversationsNavigationController = nil;
    
    _myIdentityViewController = nil;
    _settingsViewController = nil;
}

- (BOOL)shouldAutorotate {
    if ([self.presentedViewController isKindOfClass:[PortraitNavigationController class]]) {
        return NO;
    }
    return YES;
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
    if([[UserSettings sharedUserSettings] newChatViewActive]) {
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
                
            }else{
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

        return;
    }
    
    // TODO: (IOS-2860) Remove when new chat view released
    // Old ChatView iPad
    if (_old_ChatViewController == nil) {
        Conversation *conv = [_conversationsViewController getFirstConversation];
        if (conv) {
            _old_ChatViewController = [Old_ChatViewControllerCache controllerForConversation:conv];
        }
    }
    
    if (_old_ChatViewController) {
        if ([_old_ChatViewController conversation].conversationCategory == ConversationCategoryPrivate && !AppDelegate.sharedAppDelegate.isAppLocked){
            [self presentPasscodeView];
            
        }else{
            [self removeCoverView];
            UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
            _old_ChatViewController.delegate = _conversationsViewController;
            [navigationController setViewControllers:@[_old_ChatViewController]];
            [_conversationsViewController setSelectionFor: _old_ChatViewController.conversation];
            
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
    if (_myIdentityViewController == nil) {
        _myIdentityViewController = (MyIdentityViewController *)[self loadMyIdentityControllerNamed:@"myIdentityViewController"];
    }
    
    [self showModal:_myIdentityViewController];
}

- (void)showSettings {
    if (_settingsViewController == nil) {
        _settingsViewController = (SettingsViewController *)[self loadSettingsControllerNamed:@"settingsViewController"];
    }
    
    [self showModal:_settingsViewController];
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
    UIStoryboard *storyboard = [AppDelegate getSettingsStoryboard];
    return [storyboard instantiateViewControllerWithIdentifier:viewControllerName];
}

- (UIViewController *)loadMyIdentityControllerNamed:(NSString *)viewControllerName {
    UIStoryboard *storyboard = [AppDelegate getMyIdentityStoryboard];
    return [storyboard instantiateViewControllerWithIdentifier:viewControllerName];
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
    _old_ChatViewController = nil;
    _conversationsViewController = nil;
    _conversationsNavigationController = nil;
}

- (void)showMultiDeviceWizard {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MultiDeviceWizardManager shared] continueWizard];
        [self presentViewController:[[MultiDeviceWizardManager shared] wizardViewController] animated:true completion:nil];
    });
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
    UIViewController *notificationViewController = [self loadSettingsControllerNamed:@"GlobalNotificationSettingsViewController"];
    
    if(SYSTEM_IS_IPAD) {
        UIViewController *settings = [self loadSettingsControllerNamed:@"settingsViewController"];
        ModalNavigationController *navigationController = [[ModalNavigationController alloc] init];
        navigationController.showDoneButton = YES;
        navigationController.dismissOnTapOutside = YES;
        navigationController.modalDelegate = self;
        
        [navigationController pushViewController:settings animated:NO];
        [navigationController pushViewController:notificationViewController animated:NO];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
    else {
        _settingsNavigationController = self.viewControllers[kSettingsTabBarIndex];
        [_settingsNavigationController popToRootViewControllerAnimated:false];
        [_settingsNavigationController pushViewController:notificationViewController animated:false];
        [self setSelectedViewController:_settingsNavigationController];
    }
}

- (void)selectedConversation:(NSNotification*)notification {
    [self hideModal];
    if(![[UserSettings sharedUserSettings] newChatViewActive]) {
        _old_ChatViewController = [Old_ChatViewControllerCache controllerForNotificationInfo:notification.userInfo];
        if (_old_ChatViewController == nil) {
            // return if the conversation doesn't exists
            DDLogWarn(@"Unable to load chat view for selected conversation.");
            return;
        }
    }
    
    if (SYSTEM_IS_IPAD) {
        if (self.selectedIndex == kChatTabBarIndex) {
            Conversation *conv = [Old_ChatViewControllerCache getConversationForNotificationInfo:notification.userInfo createIfNotExisting:YES];
            [self switchConversation: conv notification:notification];
        } else {
            [self setSelectedIndex:kChatTabBarIndex];
            Conversation *conv = [Old_ChatViewControllerCache getConversationForNotificationInfo:notification.userInfo createIfNotExisting:YES];
            [self switchConversation: conv notification:notification];
        }
    } else {
        // New ChatView iPhone
        if ([[UserSettings sharedUserSettings] newChatViewActive]) {
            if (_conversationsViewController == nil) {
                _conversationsNavigationController = self.viewControllers[kChatTabBarIndex];
            }
            ShowConversationInformation* info = [ShowConversationInformation createInfoFor:notification];
            Conversation *conv = [Old_ChatViewControllerCache getConversationForNotificationInfo:notification.userInfo createIfNotExisting:YES];
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
                _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
                [_conversationsViewController displayChatWithChatViewController: chatViewController animated:YES];
                [self setSelectedViewController:_conversationsNavigationController];
            }
            
            return;
        }
        
        // TODO: (IOS-2860) Remove when new chat view released
        // Old ChatView iPhone
        if (_conversationsViewController == nil) {
            _conversationsNavigationController = self.viewControllers[kChatTabBarIndex];
        }
        
        if ([_conversationsNavigationController.topViewController isKindOfClass:[ArchivedConversationsViewController class]]) {
            _archivedConversationsViewController = (ArchivedConversationsViewController *) _conversationsNavigationController.topViewController;
            [_archivedConversationsViewController displayOldChatWithOldChatViewController: _old_ChatViewController animated:YES];
            [self setSelectedViewController:_conversationsNavigationController];
            
        } else if ([_conversationsNavigationController.topViewController isKindOfClass:[ConversationsViewController class]]) {
            _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
            [_conversationsViewController displayOldChatWithOldChatViewController: _old_ChatViewController animated:YES];
            [self setSelectedViewController:_conversationsNavigationController];
        }
        else {
            
            // Check if open chat is same we want to open
            if ([_conversationsNavigationController.topViewController isKindOfClass:[Old_ChatViewController class]]) {
                Old_ChatViewController * topChatViewController = (Old_ChatViewController *) _conversationsNavigationController.topViewController;
                if (topChatViewController.conversation == _old_ChatViewController.conversation) {
                    return;
                }
            }
            
            [_conversationsNavigationController popToRootViewControllerAnimated:NO];
            _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
            [_conversationsViewController displayOldChatWithOldChatViewController: _old_ChatViewController animated:YES];
            [self setSelectedViewController:_conversationsNavigationController];
        }
    }
}

- (void)deletedConversation:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        Conversation *deletedConversation = [Old_ChatViewControllerCache getConversationForNotificationInfo:notification.userInfo createIfNotExisting:NO];
        Conversation *selectedConversation = [_conversationsViewController selectedConversation];
        if (selectedConversation == deletedConversation) {
            _old_ChatViewController = nil;
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

- (void)deletedContact:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        ContactEntity *deletedContact = [notification.userInfo objectForKey:kKeyContact];
        if (_singleDetailViewController._contact == deletedContact) {
            _singleDetailViewController = nil;
            if (self.selectedIndex == kContactsTabBarIndex) {
                [self switchContact];
            }
        }
        
        if([[UserSettings sharedUserSettings] newChatViewActive]) {
            UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
            ChatViewController *chatViewController = navigationController.viewControllers.firstObject;
            if (chatViewController.conversation.willBeDeleted) {
                _conversationsViewController.selectedConversation = nil;
                [self switchConversation:nil notification:nil];
            }
        }
        else {
            if (!_old_ChatViewController.conversation.isGroup && _old_ChatViewController.conversation.contact == nil) {
                _old_ChatViewController = nil;
                [self switchConversation:nil notification:nil];
            }
        }
    }
}

- (void)showSafeSetup:(NSNotification*)notification {
    // switch to My Identity tab and show Threema Safe settings/setup
    [self setSelectedIndex:kMyIdentityTabBarIndex];
    
    UINavigationController *myIdentityNavigation = [[self viewControllers] objectAtIndex:kMyIdentityTabBarIndex];
    MyIdentityViewController *myIdentity = [[myIdentityNavigation viewControllers] objectAtIndex:0];
    if (myIdentity != nil) {
        [myIdentity showSafeSetup];
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
    [self resetChats];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    DDLogInfo(@"Color theme changed, removing cached chat view controllers");
    
    [AvatarMaker clearCache];
    [Colors updateWithWindow:[[AppDelegate sharedAppDelegate] window]];
    [Colors updateWithNavigationBar:self.selectedViewController.navigationController.navigationBar];
    [Colors updateWithTabBar:self.tabBar];
    
    [Old_ChatViewControllerCache refresh];
    
    [self setNeedsStatusBarAppearanceUpdate];
    
    if (SYSTEM_IS_IPAD) {
        [_settingsViewController refresh];
        [Colors updateWithNavigationBar:_settingsViewController.navigationController.navigationBar];
        
        [_myIdentityViewController refresh];
        [Colors updateWithNavigationBar:_myIdentityViewController.navigationController.navigationBar];
        
        [_singleDetailViewController refresh];
        [Colors updateWithNavigationBar:_singleDetailViewController.navigationController.navigationBar];
        [_contactsViewController refresh];
        [Colors updateWithNavigationBar:_contactsViewController.navigationController.navigationBar];
        
        [_conversationsViewController refresh];
        [Colors updateWithNavigationBar:_conversationsViewController.navigationController.navigationBar];
        
        [Colors updateWithNavigationBar:_old_ChatViewController.navigationController.navigationBar];
        [_old_ChatViewController refresh];
        
        for (UIViewController *vc in _conversationsNavigationController.viewControllers) {
            [Colors updateWithNavigationBar:vc.navigationController.navigationBar];
        }
        
        [Colors updateWithNavigationBar:_conversationsNavigationController.navigationBar];
    }
}

- (void)voiceOverStatusDidChange {
    [UserSettings resetSharedInstance];
}

// TODO: (IOS-2860) Remove
- (void)chatFontSizeChanged:(NSNotification*)notification {
    if ([[UserSettings sharedUserSettings] newChatViewActive]) {
        return;
    }
    DDLogInfo(@"Chat font size changed, removing cached chat view controllers");
    [self resetChats];
}

// TODO: (IOS-2860) Investigate if still needed
- (void)resetChats {
    [Old_ChatViewControllerCache clearCache];
    
    [self resetDisplayedChat];
}

- (void)resetDisplayedChat {
    if (SYSTEM_IS_IPAD) {
        if([[UserSettings sharedUserSettings] newChatViewActive]) {
            Conversation *selectedConversation = [_conversationsViewController selectedConversation];
            [self switchConversation:selectedConversation notification:nil];
        }
        else {
            if (_old_ChatViewController) {
                Conversation *conversation = _old_ChatViewController.conversation;
                _old_ChatViewController = [Old_ChatViewControllerCache controllerForConversation:conversation];
                [self switchConversation: nil notification:nil];
            }
        }
    } else {
        if (self.selectedIndex == kChatTabBarIndex) {
            [_conversationsNavigationController popToRootViewControllerAnimated:true];
        }
    }
}

#pragma mark - ModalNavigationControllerDelegate

- (void)willDismissModalNavigationController {
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
    
    if ([[UserSettings sharedUserSettings] newChatViewActive]) {
        return;
    }
    
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        [self resetChats];
    }
}


# pragma mark - JKLLockscreen Delegate
// Used for private chats on iPad
- (void) presentPasscodeView{
    JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
    vc.dataSource = self;
    vc.delegate = self;
    if([[KKPasscodeLock sharedLock] isPasscodeRequired]) {
        vc.lockScreenMode = LockScreenModeExtension;
    }
    else {
        vc.lockScreenMode = LockScreenModeNew;
    }
    
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

- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController *)viewController{
    [self removeCoverView];
    UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
    
    if([[UserSettings sharedUserSettings] newChatViewActive]) {
        Conversation *conversation = [_conversationsViewController getFirstConversation];
        ChatViewController *chatViewController = [[ChatViewController alloc]initWithConversation: conversation showConversationInformation:nil];
        [navigationController setViewControllers:@[chatViewController]];
        [_conversationsViewController setSelectionFor: conversation];
        
    } else {
        _old_ChatViewController.delegate = _conversationsViewController;
        [navigationController setViewControllers:@[_old_ChatViewController]];
        [_conversationsViewController setSelectionFor: _old_ChatViewController.conversation];
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
