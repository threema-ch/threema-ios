#import "NewMessageToaster.h"
#import "UserSettings.h"
#import "AppDelegate.h"
#import "UIDefines.h"
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessageReceived:) name:IncomingMessageManager.inAppNotificationNewMessage object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversationOpened:) name:kNotificationOpenedConversation object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)newMessageReceived:(NSNotification*)notification {
    DDLogVerbose(@"newMessageReceived: %@", notification);

    NSManagedObjectID *messageObjectID = (NSManagedObjectID *)notification.object;
    if (messageObjectID) {
        EntityManager *entityManager = [[BusinessInjector ui] entityManager];
        [entityManager performBlock:^{
            BaseMessageEntity *message = (BaseMessageEntity *)[[entityManager entityFetcher] existingObjectWith:messageObjectID];
            
            if(message == nil){
                return;
            }
            
            // don't show toast for suppressed group ids
            if (![PushSettingManagerObjC canSendPushFor:message entityManager:entityManager]) {
                return;
            }

            /* No toast if disabled, a system message or passcode showing */
            if (![UserSettings sharedUserSettings].inAppPreview ||
                [message isKindOfClass:[SystemMessageEntity class]] || [AppDelegate sharedAppDelegate].isAppLocked)
                return;
            
            /* Are we currently in the foreground? */
            if (![AppDelegate sharedAppDelegate].active) {
                [queue addObject:notification];
                return;
            }
            
            AppDelegate *appDelegate = [AppDelegate sharedAppDelegate];
            
            /* Is this for the currently visible conversation? */
            UITabBarController *mainTabBar = [appDelegate tabBarController];
            if ([mainTabBar viewControllers].count <= kChatTabBarIndex) {
                return;
            }
            UINavigationController *chatNavVc = [[mainTabBar viewControllers] objectAtIndex:kChatTabBarIndex];
            
            if ([chatNavVc.topViewController isKindOfClass:[ChatViewController class]]) {
                ChatViewController *curChatVc = (ChatViewController*)chatNavVc.topViewController;
                if (curChatVc.conversation.objectID == message.conversation.objectID) {
                    if (UIAccessibilityIsVoiceOverRunning() && (![curChatVc isRecording] && ![curChatVc isPlayingAudioMessage])) {
                        NSString *accessibilityText = [self accessibilityTextFor:message];
                        if (accessibilityText != nil) {
                            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, accessibilityText);
                        }
                    }
                    return;
                }
            }
            
            __block BOOL canDisplayNotification = YES;
            
            [appDelegate execute:^(AppCoordinator *coordinator) {
                canDisplayNotification = [coordinator canDisplayNotificationToastFor:message];
            }];
            
            if (canDisplayNotification == NO) {
                return;
            }
            
            [NotificationBannerHelper newBannerWithBaseMessage:message];
        }];
    }
}

- (void)conversationOpened:(NSNotification*)notification {
    NSString *identifier = notification.object;
    if (identifier != nil) {
        [NotificationBannerHelper dismissAllNotificationsFor:identifier];
    }
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
