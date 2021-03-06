//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "NewMessageToaster.h"
#import "BaseMessage.h"
#import "UserSettings.h"
#import "SystemMessage.h"
#import "Conversation.h"
#import "Contact.h"
#import "ChatViewController.h"
#import "AppDelegate.h"
#import "UIDefines.h"
#import "ConversationsViewController.h"
#import "AvatarMaker.h"
#import "TextStyleUtils.h"
#import "PushSetting.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation NewMessageToaster {
    NSMutableArray *queue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        queue = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessageReceived:) name:@"ThreemaNewMessageReceived" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationOpened:) name:@"ThreemaConversationOpened" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenRotated:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)newMessageReceived:(NSNotification*)notification {
    BaseMessage *message = notification.object;
    
    DDLogVerbose(@"newMessageReceived: %@", notification);
    
    if (![message.read boolValue]) {
        NSString *identity = message.sender.identity;
        if (identity == nil) {
            identity = message.conversation.contact.identity;
        }
        
        // don't show toast for suppressed group ids
        PushSetting *pushSetting = [PushSetting findPushSettingForIdentity:identity];
        if (pushSetting != nil) {
            if (![pushSetting canSendPushForBaseMessage:message]) {
                return;
            }
        }
        
        /* No toast if disabled, a system message or passcode showing */
        if (![UserSettings sharedUserSettings].inAppPreview ||
            [message isKindOfClass:[SystemMessage class]] || [AppDelegate sharedAppDelegate].isAppLocked)
            return;
        
        /* Are we currently in the foreground? */
        if (![AppDelegate sharedAppDelegate].active) {
            [queue addObject:notification];
            return;
        }
        
        /* Is this for the currently visible conversation? */
        UITabBarController *mainTabBar = [AppDelegate getMainTabBarController];
        if ([mainTabBar viewControllers].count <= kChatTabBarIndex) {
            return;
        }
        UINavigationController *chatNavVc = [[mainTabBar viewControllers] objectAtIndex:kChatTabBarIndex];
        
        DDLogVerbose(@"curNavController: %@", chatNavVc);
        if ([chatNavVc.topViewController isKindOfClass:[ChatViewController class]]) {
            ChatViewController *curChatVc = (ChatViewController*)chatNavVc.topViewController;
            if (curChatVc.conversation == message.conversation)
                return;
        }
        
        [NotificationBannerHelper newBannerWithMessage: message];
    }
}

- (void)conversationOpened:(NSNotification*)notification {
    Conversation *conversation = notification.object;
    if (conversation != nil) {
        [NotificationBannerHelper dismissAllNotificationsFor:conversation];
    }
}

- (void)screenRotated:(NSNotification*)notification {
    DDLogVerbose(@"screenRotated");
    [NotificationBannerHelper dismissAllNotifications];
}

- (void)didBecomeActive:(NSNotification*)notification {
    DDLogVerbose(@"didBecomeActive");
    
    if (![AppDelegate sharedAppDelegate].active)
        return; /* safety check */
    
    /* show any queued notifications now */
    for (NSNotification *queuedNotification in queue) {
        [self newMessageReceived:queuedNotification];
    }
    
    [queue removeAllObjects];
}

@end
