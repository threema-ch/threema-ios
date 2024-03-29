//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "MessageDraftStore.h"
#import "ContactEntity.h"
#import "Conversation.h"
#import "NSString+Hex.h"
#import "AppGroup.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation MessageDraftStore

+ (void)saveDraft:(NSString*)draft forConversation:(Conversation*)conversation {
    NSString *storeKey = [MessageDraftStore storeKeyForConversation:conversation];
    if (storeKey == nil)
        return;
    
    NSDictionary *messageDrafts = [[AppGroup userDefaults] dictionaryForKey:@"MessageDrafts"];
    if (messageDrafts == nil) {
        messageDrafts = [NSDictionary dictionary];
    }
    
    NSMutableDictionary *newMessageDrafts = [NSMutableDictionary dictionaryWithDictionary:messageDrafts];
    if (draft.length == 0) {
        [newMessageDrafts removeObjectForKey:storeKey];
    } else {
        [newMessageDrafts setObject:draft forKey:storeKey];
    }
    
    [[AppGroup userDefaults] setObject:newMessageDrafts forKey:@"MessageDrafts"];
    [[AppGroup userDefaults] synchronize];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kNotificationUpdateDraftForCell object:nil userInfo: @{kKeyConversation: conversation}];
}

+ (void)deleteDraftForConversation:(Conversation *)conversation {
    NSString *storeKey = [MessageDraftStore storeKeyForConversation:conversation];
    if (storeKey == nil)
        return;
    
    NSDictionary *messageDrafts = [[AppGroup userDefaults] dictionaryForKey:@"MessageDrafts"];
    if (messageDrafts == nil || [messageDrafts objectForKey:storeKey] == nil) {
        return;
    }
    
    NSMutableDictionary *newMessageDrafts = [NSMutableDictionary dictionaryWithDictionary:messageDrafts];
    [newMessageDrafts removeObjectForKey:storeKey];
    [[AppGroup userDefaults] setObject:newMessageDrafts forKey:@"MessageDrafts"];
    [[AppGroup userDefaults] synchronize];
    
    [NSNotificationCenter.defaultCenter postNotificationName:kNotificationUpdateDraftForCell object:nil userInfo: @{kKeyConversation: conversation}];
}

+ (NSString *)loadDraftForConversation:(Conversation *)conversation {
    NSString *storeKey = [MessageDraftStore storeKeyForConversation:conversation];
    if (storeKey == nil)
        return nil;
    
    NSDictionary *messageDrafts = [[AppGroup userDefaults] dictionaryForKey:@"MessageDrafts"];
    return [messageDrafts objectForKey:storeKey];
}

/// Removes drafts where the conversation is already deleted
+ (void)cleanupDrafts {
    NSUserDefaults *defaults = [AppGroup userDefaults];
    if ([defaults boolForKey:@"AlreadyDeletedOldDrafts"]) {
        return;
    }
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performBlockAndWait:^{
        NSArray *allContacts = [entityManager.entityFetcher allContacts];
        NSMutableDictionary *newMessageDrafts = [NSMutableDictionary new];

        for (ContactEntity *contact in allContacts) {
            for (Conversation *conv in contact.conversations) {
                NSString *draft = [self loadDraftForConversation:conv];
                if(draft != nil){
                    NSString * __nonnull storeKey = [MessageDraftStore storeKeyForConversation:conv];
                    [newMessageDrafts setObject:draft forKey: storeKey];
                }
            }
        }
        [defaults setObject:newMessageDrafts forKey:@"MessageDrafts"];
        [defaults setBool:YES forKey:@"AlreadyDeletedOldDrafts"];
        [defaults synchronize];
    }];
}

+ (NSString*)storeKeyForConversation:(Conversation*)conversation {
    if ([conversation isGroup]) {
        NSString *creator = conversation.contact.identity;
        if (creator == nil)
            creator = @"*";
        return [NSString stringWithFormat:@"%@-%@", creator, [NSString stringWithHexData:conversation.groupId]];
    } else {
        return conversation.contact.identity;
    }
}

@end
