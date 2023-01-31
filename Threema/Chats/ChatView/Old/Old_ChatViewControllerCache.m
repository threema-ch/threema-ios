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

#import "Old_ChatViewControllerCache.h"
#import "AppDelegate.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation Old_ChatViewControllerCache

static NSMutableDictionary *cache;

+ (void)initialize {
    if (self == [Old_ChatViewControllerCache self]) {
        cache = [NSMutableDictionary dictionary];
    }
}

+ (Old_ChatViewController *)newControllerForConversation:(Conversation *)conversation forceTouch:(BOOL)forceTouch {
    UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
    Old_ChatViewController *controller = (Old_ChatViewController *)[storyboard instantiateViewControllerWithIdentifier:@"chatViewController"];
    controller.conversation = conversation;
    controller.isOpenWithForceTouch = forceTouch;
    
    if (SYSTEM_IS_IPAD) {
        controller.hidesBottomBarWhenPushed = NO;
    }
    
    return controller;
}

+ (Old_ChatViewController *)controllerForConversation:(Conversation *)conversation {
    @synchronized(cache) {
        Old_ChatViewController *controller = [cache objectForKey:conversation.objectID];
        if (controller == nil) {
            controller = [self newControllerForConversation:conversation forceTouch:NO];
            [cache setObject:controller forKey:conversation.objectID];
        }
        
        return controller;
    }
}

+ (Old_ChatViewController *)controllerForNotificationInfo:(NSDictionary *)info {
    Conversation *conversation = [self getConversationForNotificationInfo:info createIfNotExisting:YES];
    if (conversation) {
        Old_ChatViewController *controller = [self controllerForConversation:conversation];
        if (controller) {
            [self setupController:controller withInfo:info];
        }
        return controller;
    }
    
    return nil;
}

+ (void)addInitializedController:(Old_ChatViewController *)controller {
    @synchronized(cache) {
        [cache setObject:controller forKey:controller.conversation.objectID];
    }
}

+ (void)clearCache {
    @synchronized(cache) {
        [cache removeAllObjects];
    }
}

+ (void)refresh {
    for (Old_ChatViewController *vc in [cache allValues]) {
        [vc refresh];
    }
}

+ (void)clearConversation:(Conversation *)conversation {
    @synchronized(cache) {
        if (conversation) {
            [cache removeObjectForKey:conversation];
        }
    }
}

+ (Conversation *)getConversationForNotificationInfo:(NSDictionary *)info createIfNotExisting:(BOOL)createIfNotExisting {
    __block Conversation *conversation = [info objectForKey:kKeyConversation];
    __block Contact *notificationContact = [info objectForKey:kKeyContact];
    if (conversation == nil) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            Contact *contact = (Contact *)[entityManager.entityFetcher getManagedObjectById:notificationContact.objectID];
            if (contact) {
                conversation = [entityManager conversationForContact:contact createIfNotExisting:createIfNotExisting];
            }
        }];
    }
    
    return conversation;
}

#pragma mark - private

+ (void)setupController:(Old_ChatViewController *)controller withInfo:(NSDictionary *)info {
    NSNumber *forceComposeNumber = [info objectForKey:kKeyForceCompose];
    BOOL forceCompose = forceComposeNumber ? forceComposeNumber.boolValue : NO;
    if (forceCompose) {
        controller.composing = YES;
    }
    
    NSString *text = [info objectForKey:kKeyText];
    if (text) {
        controller.messageText = text;
    }
    
    UIImage *image = [info objectForKey:kKeyImage];
    if (image) {
        controller.imageDataToSend = UIImageJPEGRepresentation(image, 1.0);
    }
}

@end
