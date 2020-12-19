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

#import "ChatViewControllerCache.h"
#import "EntityManager.h"
#import "AppDelegate.h"

@implementation ChatViewControllerCache

static NSMutableDictionary *cache;

+ (void)initialize {
    if (self == [ChatViewControllerCache self]) {
        cache = [NSMutableDictionary dictionary];
    }
}

+ (ChatViewController *)newControllerForConversation:(Conversation *)conversation forceTouch:(BOOL)forceTouch {
    UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
    ChatViewController *controller = (ChatViewController *)[storyboard instantiateViewControllerWithIdentifier:@"chatViewController"];
    controller.conversation = conversation;
    controller.isOpenWithForceTouch = forceTouch;
    
    if (SYSTEM_IS_IPAD) {
        controller.hidesBottomBarWhenPushed = NO;
    }
    
    return controller;
}

+ (ChatViewController *)controllerForConversation:(Conversation *)conversation {
    @synchronized(cache) {
        ChatViewController *controller = [cache objectForKey:conversation.objectID];
        if (controller == nil) {
            controller = [self newControllerForConversation:conversation forceTouch:NO];
            [cache setObject:controller forKey:conversation.objectID];
        }
        
        return controller;
    }
}

+ (ChatViewController *)controllerForNotificationInfo:(NSDictionary *)info {
    Conversation *conversation = [self getConversationForNotificationInfo:info];
    
    ChatViewController *controller = [self controllerForConversation:conversation];
    if (controller) {
        [self setupController:controller withInfo:info];
    }
    
    return controller;
}

+ (void)addInitializedController:(ChatViewController *)controller {
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
    for (ChatViewController *vc in [cache allValues]) {
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

+ (Conversation *)getConversationForNotificationInfo:(NSDictionary *)info {
    __block Conversation *conversation = [info objectForKey:kKeyConversation];
    if (conversation == nil) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            Contact *contact = [info objectForKey:kKeyContact];
            if (contact) {
                conversation = [entityManager conversationForContact:contact createIfNotExisting:YES];
            }
        }];
    }
    
    return conversation;
}

#pragma mark - private

+ (void)setupController:(ChatViewController *)controller withInfo:(NSDictionary *)info {
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
        controller.imageDataToSend = image;
    }
}

@end
