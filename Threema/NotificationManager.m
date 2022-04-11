//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

#import "NotificationManager.h"
#import "UserSettings.h"
#import <UserNotifications/UserNotifications.h>
#import <PushKit/PushKit.h>
#import "NSString+Hex.h"
#import "AppDelegate.h"
#import "EntityFetcher.h"
#import "UIDefines.h"
#import <AudioToolbox/AudioToolbox.h>
#import "BundleUtil.h"
#import "PushPayloadDecryptor.h"
#import "ContactStore.h"
#import "AppGroup.h"
#import "ServerConnector.h"
#import "TextStyleUtils.h"
#import "Threema-Swift.h"

#import "AbstractGroupMessage.h"
#import "Conversation.h"
#import "Contact.h"
#import "GroupImageMessage.h"
#import "GroupVideoMessage.h"
#import "ImageMessage.h"
#import "VideoMessage.h"
#import "BoxImageMessage.h"
#import "BoxVideoMessage.h"

#import "ValidationLogger.h"

@implementation NotificationManager {
    SystemSoundID receivedMessageSound;
    CFTimeInterval lastReceivedMessageSound;
}

+ (NotificationManager *)sharedInstance {
    static NotificationManager *sharedInstance;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[NotificationManager alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        /* Get sounds ready */
        NSString *soundPath = [BundleUtil pathForResource:@"received_message" ofType:@"caf"];
        CFURLRef baseURL = (__bridge CFURLRef)[NSURL fileURLWithPath:soundPath];
        AudioServicesCreateSystemSoundID(baseURL, &receivedMessageSound);
    }
    return self;
}

- (void)updateUnreadMessagesCount:(BOOL)unloadedMessage {
    NSDictionary *unreadDict = [self unreadMessagesCount:unloadedMessage];
    NSNumber *badgeCount = unreadDict[@"badgeCount"];
    NSNumber *markedCount = unreadDict[@"markedCount"];
    int totalCount = badgeCount.intValue + markedCount.intValue;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaUnreadMessagesCountChanged" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:totalCount] forKey:@"unread"]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].applicationIconBadgeNumber = totalCount;
    });
}

- (NSDictionary *)unreadMessagesCount:(BOOL)unloadedMessage {
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSArray *conversations = [entityManager.entityFetcher allConversations];
    int unread = 0;
    int markedConversations = 0;
    
    if (unloadedMessage)
        unread++;
    
    for (Conversation *conversation in conversations) {
        int count = [conversation.unreadMessageCount intValue];
        if (count > 0) {
            unread += [conversation.unreadMessageCount intValue];
        }
        else if (count == -1) {
            markedConversations += 1;
        }
    }
    
    NSString *badgeValue = nil;
    if (unread + markedConversations > 0)
        badgeValue = [NSString stringWithFormat:@"%d", unread + markedConversations];
    
    __block UITabBarController *mainTabBar;
    if ([NSThread isMainThread]) {
        mainTabBar = [AppDelegate getMainTabBarController];
        
        if (mainTabBar && [mainTabBar isKindOfClass:[UITabBarController class]]) {
            [[mainTabBar.tabBar.items objectAtIndex:kChatTabBarIndex] setBadgeValue:badgeValue];
        }
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            mainTabBar = [AppDelegate getMainTabBarController];
            
            if (mainTabBar && [mainTabBar isKindOfClass:[UITabBarController class]]) {
                [[mainTabBar.tabBar.items objectAtIndex:kChatTabBarIndex] setBadgeValue:badgeValue];
            }
        });
    }
    
    return @{@"badgeCount": [NSNumber numberWithInt:unread], @"markedCount": [NSNumber numberWithInt:markedConversations]};
}

- (void)handleVoIPPush:(NSDictionary *)payload withCompletionHandler:(void (^)(void))completion {
    if ([[MyIdentityStore sharedMyIdentityStore] isKeychainLocked]) {
        if (payload[@"threema"] != nil) {
            [NotificationManager showNoAccessToDatabaseNotification:^{
                    exit(0);
            }];
        }
        
        // The keychain is locked; we cannot proceed. The UI will show the ProtectedDataUnavailable screen
        // at this point. To prevent this screen from appearing when the user unlocks their device after we
        // have processed the push, we exit now so that the process will restart after the device is unlocked.
    }
    else {
        WebClientSession *currentSession = nil;
    
        if (payload[@"3mw"] != nil) {
            NSDictionary *webPayload = payload[@"3mw"];
            if (webPayload[@"wcs"] != nil) {
                currentSession = [[WebClientSessionStore shared] webClientSessionForHash:webPayload[@"wcs"]];
            }
            
            if (currentSession != nil) {
                int webClientProtocolVersion = [webPayload[@"wcv"] intValue];
                if (![currentSession.version isEqualToNumber:[NSNumber numberWithInt:webClientProtocolVersion]]) {
                    // show error
                    NSString *title;
                    NSString *body;
                    if (webClientProtocolVersion > [currentSession.version intValue]) {
                        title = NSLocalizedString(@"webClientSession_error_updateApp_title", nil);
                        body = NSLocalizedString(@"webClientSession_error_updateApp_message", nil);
                    } else {
                        if ([currentSession.selfHosted boolValue] == YES) {
                            title = NSLocalizedString(@"webClientSession_error_updateServer_title", nil);
                            body = NSLocalizedString(@"webClientSession_error_updateServer_message", nil);
                        } else {
                            title = NSLocalizedString(@"webClientSession_error_wrongVersion_title", nil);
                            body = NSLocalizedString(@"webClientSession_error_wrongVersion_message", nil);
                        }
                    }
                    
                    [self showThreemaWebErrorWithTitle:title body:body];
                    [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
                    completion();
                    return;
                }
                
                [self loadMessages:payload currentSession:currentSession withCompletionHandler:completion];
            } else {
                [[ValidationLogger sharedValidationLogger] logString:@"Threema Web: Unknown session try to connect; Session blocked"];
                [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
                completion();
            }
        } else {
            [self loadMessages:payload currentSession:currentSession withCompletionHandler:completion];
        }
    }
}

- (void)loadMessages:(NSDictionary *)payload currentSession:(WebClientSession *)currentSession withCompletionHandler:(void (^)(void))completion {
    NSDictionary *threemaDict = [PushPayloadDecryptor decryptPushPayload:payload[ThreemaPushNotificationDictionaryKey]];
    NSString *messageId = threemaDict[ThreemaPushNotificationDictionaryMessageIdKey];
    NSString *senderId = threemaDict[ThreemaPushNotificationDictionaryFromKey];
    
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Push: Received Push Notification for %@", messageId]];
    
    if (payload[@"3mw"] != nil) {
        if (currentSession != nil) {
            [[WCSessionManager shared] connectWithAuthToken:nil wca: payload[@"wca"] webClientSession:currentSession];
            [[DatabaseManager dbManager] refreshDirtyObjects];
        } else {
            // there is no local connection
            [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
            completion();
            return;
        }
        
        [[ServerConnector sharedServerConnector] connect];
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && [[WCSessionManager shared] isRunningWCSession]) {
            [[BackgroundTaskManager shared] newBackgroundTaskWithKey:kAppWCBackgroundTask timeout:kAppWCBackgroundTaskTime completionHandler:^{
                [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
                completion();
            }];
        } else {
            [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
            completion();
        }
    } else {
        if (senderId == nil && messageId == nil && threemaDict == nil) {
            [PendingMessage createTestNotificationWithPayload:payload completion:^{
                [[BackgroundTaskManager shared] cancelBackgroundTaskWithKey:kAppPushBackgroundTask];
                completion();
            }];
        } else {
            [[ValidationLogger sharedValidationLogger] logString:@"Threema Web: loadMessages --> connect all running sessions"];
            [[WCSessionManager shared] connectAllRunningSessions];
            [[DatabaseManager dbManager] refreshDirtyObjects];
            [[PendingMessagesManager shared] pendingMessageWithSenderId:senderId messageId:messageId abstractMessage:nil threemaDict:threemaDict completion:^(PendingMessage *pendingMessage) {
                [[BackgroundTaskManager shared] newBackgroundTaskWithKey:kAppPushBackgroundTask timeout:kAppPushBackgroundTaskTime completionHandler:^{
                    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive && [[WCSessionManager shared] isRunningWCSession]) {
                        [[BackgroundTaskManager shared] newBackgroundTaskWithKey:kAppWCBackgroundTask timeout:kAppWCBackgroundTaskTime completionHandler:nil];
                    }
                    if (pendingMessage != nil) {
                        pendingMessage.completionHandler = completion;
                    } else {
                        completion();
                    }
                    [[ServerConnector sharedServerConnector] connect];
                }];
            }];
        }
    }
}


#pragma mark - Private functions

- (void)showThreemaWebErrorWithTitle:(NSString *)title body:(NSString *)body {
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        UNMutableNotificationContent *notification = [[UNMutableNotificationContent alloc] init];
        
        notification.title = title;
        notification.body = body;
        
        if (![[UserSettings sharedUserSettings].pushSound isEqualToString:@"none"]) {
            notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"%@.caf", [UserSettings sharedUserSettings].pushSound]];
        }
        
        UNNotificationRequest *notificationRequest = [UNNotificationRequest requestWithIdentifier:@"ThreemaWebError" content:notification trigger:nil];
        
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
        }];
    } else {
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:title message:body actionOk:nil];
    }
}

- (void)playReceivedMessageSound {
    CFTimeInterval curTime = CACurrentMediaTime();
    
    /* play sound only twice per second */
    if (curTime - lastReceivedMessageSound > 0.5) {
        if ([UserSettings sharedUserSettings].inAppSounds && [UserSettings sharedUserSettings].inAppVibrate)
            AudioServicesPlayAlertSound(receivedMessageSound);
        else if ([UserSettings sharedUserSettings].inAppSounds)
            AudioServicesPlaySystemSound(receivedMessageSound);
        else if ([UserSettings sharedUserSettings].inAppVibrate)
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    }
    lastReceivedMessageSound = curTime;
}

#pragma mark - Static functions

/// Show no access to database error
/// @param onCompletion This is called after 2 seconds to be sure the notification is fired
+ (void)showNoAccessToDatabaseNotification:(void(^)(void))onCompletion {
    [Utils sendErrorLocalNotification:NSLocalizedString(@"new_message_no_access_title", @"") body:NSLocalizedString(@"new_message_no_access_message", @"") userInfo:nil onCompletion:^{
        [Utils waitForSeconds:2 finish:onCompletion];
    }];
}

/**
 Generate push settings for all groups, will be run once when upgrade app.
*/
+ (void)generatePushSettingForAllGroups {
    if ([UserSettings sharedUserSettings].pushGroupGenerated == NO) {
        NSMutableOrderedSet *pushSettings = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].pushSettingsList];
        EntityManager *entityManager = [[EntityManager alloc] init];
        NSArray *allGroupConversations = [entityManager.entityFetcher allGroupConversations];
        for (Conversation *conversation in allGroupConversations) {
            NSString *identity = [NSString stringWithHexData:conversation.groupId];
            PushSetting *pushSetting = [PushSetting findPushSettingForIdentity:identity pushSettingList:pushSettings];
            if (pushSetting == nil) {
                PushSetting *tmpPushSetting = [PushSetting new];
                tmpPushSetting.identity = identity;
                tmpPushSetting.type = kPushSettingTypeOn;
                tmpPushSetting.periodOffTime = 0;
                tmpPushSetting.periodOffTillDate = nil;
                tmpPushSetting.silent = false;
                tmpPushSetting.mentions = false;
                [pushSettings addObject:tmpPushSetting.buildDict];
            }
        }
        [[UserSettings sharedUserSettings] setPushSettingsList:pushSettings];
        [[UserSettings sharedUserSettings] setPushGroupGenerated:YES];
    }
}

@end
