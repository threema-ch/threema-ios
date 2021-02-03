//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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
#import "ContactDetailsViewController.h"
#import "GroupDetailsViewController.h"
#import "ConversationsViewController.h"
#import "ChatViewController.h"

#import "ModalNavigationController.h"
#import "MyIdentityViewController.h"
#import "PortraitNavigationController.h"

#import "EntityManager.h"
#import "ChatViewControllerCache.h"
#import "MWPhotoBrowser.h"

#import "AppGroup.h"
#import "GroupProxy.h"
#import "AvatarMaker.h"
#import "JKLLockScreenViewController.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface MainTabBarController () <ModalNavigationControllerDelegate>

@property ChatViewController *chatViewController;
@property ContactDetailsViewController *contactDetailViewController;
@property GroupDetailsViewController *groupDetailViewController;

@property ContactsViewController *contactsViewController;
@property ConversationsViewController *conversationsViewController;

@property PortraitNavigationController *contactsNavigationController;
@property PortraitNavigationController *conversationsNavigationController;

@property MyIdentityViewController *myIdentityViewController;
@property SettingsViewController *settingsViewController;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatFontSizeChanged:) name:kNotificationFontSizeChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatFontSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timestampSettingsChanged:) name:kNotificationShowTimestampSettingsChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorThemeChanged:) name:kNotificationColorThemeChanged object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    
    [Colors updateTabBar:self.tabBar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_isFirstAppearance) {
        self.selectedIndex = kDefaultInitialTabIndex;
        _isFirstAppearance = NO;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    NSUInteger index = [self.viewControllers indexOfObject:selectedViewController];
    [self setSelectedIndex:index];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    // fallback for when setting share extension inactive fails for some reason (crash etc.)
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
    
    [self switchConversation];
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

- (void)switchConversation {
    if (_chatViewController == nil) {
        Conversation *conversation = [_conversationsViewController getFirstConversation];
        if (conversation) {
            _chatViewController = [ChatViewControllerCache controllerForConversation:conversation];
        }
    }
   
    if (_chatViewController) {
        UINavigationController *navigationController = self.viewControllers[kChatTabBarIndex];
        _chatViewController.delegate = _conversationsViewController;
        [navigationController setViewControllers:@[_chatViewController]];
        [_conversationsViewController setSelectionForConversation:_chatViewController.conversation];
    } else {
        [self clearNavigationControllerAt:kChatTabBarIndex];
    }
    
    [super setSelectedIndex:kChatTabBarIndex];
}

- (void)switchContact {
    if (_contactDetailViewController) {
        UINavigationController *navigationController = self.viewControllers[kContactsTabBarIndex];
        [navigationController setViewControllers:@[_contactDetailViewController]];
        
        if ([_contactsViewController isWorkActive]) {
            [_contactsViewController setSelectionForWorkContact:_contactDetailViewController.contact];
        } else {
            [_contactsViewController setSelectionForContact:_contactDetailViewController.contact];
        }
    } else if (_groupDetailViewController) {
        UINavigationController *navigationController = self.viewControllers[kContactsTabBarIndex];
        [navigationController setViewControllers:@[_groupDetailViewController]];
        
        [_contactsViewController setSelectionForGroup:_groupDetailViewController.group];
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
    _chatViewController = nil;
    _conversationsViewController = nil;
    _conversationsNavigationController = nil;
}

#pragma mark - notifications

- (void)selectedGroup:(NSNotification*)notification {
    GroupProxy *group = [notification.userInfo objectForKey:kKeyGroup];
    
    _contactDetailViewController = nil;

    if (SYSTEM_IS_IPAD) {
        _groupDetailViewController = (GroupDetailsViewController *)[self loadViewControllerNamed:@"groupDetailsViewController"];
        _groupDetailViewController.group = group;
        
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
    Contact *contact = [notification.userInfo objectForKey:kKeyContact];
    
    _groupDetailViewController = nil;
    
    if (SYSTEM_IS_IPAD) {
        _contactDetailViewController = (ContactDetailsViewController *)[self loadViewControllerNamed:@"contactDetailsViewController"];
        _contactDetailViewController.contact = contact;
        
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
        [_contactsViewController showDetailsForContact:contact];
    }
}

- (void)selectedConversation:(NSNotification*)notification {
    [self hideModal];

    _chatViewController = [ChatViewControllerCache controllerForNotificationInfo:notification.userInfo];
    
    if (SYSTEM_IS_IPAD) {
        if (self.selectedIndex == kChatTabBarIndex) {
            [self switchConversation];
        } else {
            [self setSelectedIndex:kChatTabBarIndex];
        }
    } else {
        if (_conversationsViewController == nil) {
            _conversationsNavigationController = self.viewControllers[kChatTabBarIndex];
            
            if ([_conversationsNavigationController.topViewController isKindOfClass:[ConversationsViewController class]]) {
                _conversationsViewController = (ConversationsViewController *)_conversationsNavigationController.topViewController;
            }
        }
        
        [self setSelectedViewController:_conversationsNavigationController];
        [_conversationsViewController displayChat:_chatViewController animated:YES];
    }
}

- (void)deletedConversation:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        Conversation *deletedConversation = [ChatViewControllerCache getConversationForNotificationInfo:notification.userInfo];
        if (_chatViewController.conversation == deletedConversation) {
            _chatViewController = nil;
            if (self.selectedIndex == kChatTabBarIndex) {
                [self switchConversation];
            }
        }
        
        if (_groupDetailViewController.group.conversation == deletedConversation) {
            _groupDetailViewController = nil;
            if (self.selectedIndex == kContactsTabBarIndex) {
                [self switchContact];
            }
        }
    }
}

- (void)deletedContact:(NSNotification*)notification {
    if (SYSTEM_IS_IPAD) {
        Contact *deletedContact = [notification.userInfo objectForKey:kKeyContact];
        if (_contactDetailViewController.contact == deletedContact) {
            _contactDetailViewController = nil;
            if (self.selectedIndex == kContactsTabBarIndex) {
                [self switchContact];
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
    }
}

- (void)wallpaperChanged:(NSNotification*)notification {
    DDLogInfo(@"Wallpaper changed, removing cached chat view controllers");
    [self resetChats];
}

- (void)colorThemeChanged:(NSNotification*)notification {
    DDLogInfo(@"Color theme changed, removing cached chat view controllers");
            
    [AvatarMaker clearCache];
    [Colors updateWindow:[[AppDelegate sharedAppDelegate] window]];
    [Colors updateNavigationBar:self.selectedViewController.navigationController.navigationBar];
    [Colors updateTabBar:self.tabBar];
    
    [ChatViewControllerCache refresh];
    
    [self setNeedsStatusBarAppearanceUpdate];
    
    if (SYSTEM_IS_IPAD) {
        [_settingsViewController refresh];
        [Colors updateNavigationBar:_settingsViewController.navigationController.navigationBar];

        [_myIdentityViewController refresh];
        [Colors updateNavigationBar:_settingsViewController.navigationController.navigationBar];

        [_contactDetailViewController refresh];
        [Colors updateNavigationBar:_contactDetailViewController.navigationController.navigationBar];
        [_contactsViewController refresh];
        [Colors updateNavigationBar:_contactsViewController.navigationController.navigationBar];

        [_conversationsViewController refresh];
        [Colors updateNavigationBar:_conversationsViewController.navigationController.navigationBar];

        [Colors updateNavigationBar:_chatViewController.navigationController.navigationBar];
        [_chatViewController refresh];
        
        for (UIViewController *vc in _conversationsNavigationController.viewControllers) {
            [Colors updateNavigationBar:vc.navigationController.navigationBar];
        }
        
        [Colors updateNavigationBar:_conversationsNavigationController.navigationBar];
        
    }
}

- (void)chatFontSizeChanged:(NSNotification*)notification {
    DDLogInfo(@"Chat font size changed, removing cached chat view controllers");
    [self resetChats];
}

- (void)timestampSettingsChanged:(NSNotification*)notification {
    DDLogInfo(@"Timestamp settings changed, removing cached chat view controllers");
    [self resetChats];
}

- (void)resetChats {
    [ChatViewControllerCache clearCache];
    
    [self resetDisplayedChat];
}

- (void)resetDisplayedChat {
    if (SYSTEM_IS_IPAD) {
        if (_chatViewController) {
            Conversation *conversation = _chatViewController.conversation;
            _chatViewController = [ChatViewControllerCache controllerForConversation:conversation];
            [self switchConversation];
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
    _currentIndex = -1;
    [super setSelectedIndex:kSettingsTabBarIndex];
    [self setSelectedIndex:index];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([[UserSettings sharedUserSettings] useSystemTheme] && [[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
            if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
                if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    if ([Colors getTheme] != ColorThemeDark && [Colors getTheme] != ColorThemeDarkWork) {
                        [Colors setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeDarkWork : ColorThemeDark];
                    }
                } else {
                    if ([Colors getTheme] != ColorThemeLight && [Colors getTheme] != ColorThemeLightWork) {
                        [Colors setTheme:[LicenseStore requiresLicenseKey] ? ColorThemeLightWork : ColorThemeLight];
                    }
                }
            }
        }
    }
    
    if (previousTraitCollection.preferredContentSizeCategory != self.traitCollection.preferredContentSizeCategory) {
        [self resetChats];
    }
}

@end
