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

#import "FeatureMask.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import "ContactEntity.h"
#import "Conversation.h"
#import "ContactStore.h"
#import "UIDefines.h"
#import "AppGroup.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define kTimeTillNextFeatureMaskSet -60*60*24

@implementation FeatureMask

+ (void)updateFeatureMask {
    [FeatureMask updateFeatureMaskOnCompletion:nil];
}

+ (void)updateFeatureMaskOnCompletion:(void (^)(void))onCompletion {
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    NSUserDefaults *defaults = [AppGroup userDefaults];
    
    NSDate *lastFeatureMaskSet = [defaults objectForKey:@"LastFeatureMaskSet"];
    NSDate *lastFeatureMaskDate = [NSDate dateWithTimeIntervalSinceNow:kTimeTillNextFeatureMaskSet];
    int currentFeatureMask = [[FeatureMaskBuilder current] build];
    
    if ((!lastFeatureMaskSet || [lastFeatureMaskSet laterDate:lastFeatureMaskDate] == lastFeatureMaskDate) || (myIdentityStore == nil || !myIdentityStore.lastSentFeatureMask || myIdentityStore.lastSentFeatureMask == 0 || myIdentityStore.lastSentFeatureMask != currentFeatureMask)) {
        DDLogVerbose(@"Set feature mask %d on server", currentFeatureMask);
        ServerAPIConnector *connector = [[ServerAPIConnector alloc] init];
        [connector setFeatureMask:[NSNumber numberWithInt:currentFeatureMask] forStore:myIdentityStore onCompletion:^{
            myIdentityStore.lastSentFeatureMask = currentFeatureMask;
            [defaults setObject:[NSDate date] forKey:@"LastFeatureMaskSet"];
            [defaults synchronize];
            if (onCompletion) {
                onCompletion();
            }
        } onError:^(NSError *error) {
            DDLogError(@"Set feature mask failed: %@", error);
            myIdentityStore.lastSentFeatureMask = 0;
        }];
    } else {
        DDLogVerbose(@"Feature mask is up-to-date");
        if (onCompletion) {
            onCompletion();
        }
    }
}

+ (NSSet *)filterContactsWithUnsupportedFeatureMask:(NSInteger)featureMask fromContacts:(NSSet *)inputContacts {
    NSMutableSet *unsupportedContacts = [NSMutableSet set];
    for (ContactEntity *contact in inputContacts) {
        //make sure the object is in sync
        [contact.managedObjectContext refreshObject:contact mergeChanges:YES];
        
        if (!(featureMask & [contact.featureMask intValue])) {
            [unsupportedContacts addObject: contact];
        }
    }
    
    return unsupportedContacts;
}

+ (void)checkFeatureMask:(NSInteger)featureMask forConversations:(NSSet *)conversations onCompletion:(void (^)(NSArray *unsupportedContacts))onCompletion {
    
    NSMutableSet *contacts = [NSMutableSet set];
    
    for (Conversation *conversation in conversations) {
        if ([conversation isGroup]) {
            for (ContactEntity *contact in conversation.participants) {
                [contacts addObject:contact];
            }
        } else {
            [contacts addObject:conversation.contact];
        }
    }
    
    [self checkFeatureMask:featureMask forContacts:contacts onCompletion:onCompletion];
}

+ (void)checkFeatureMask:(NSInteger)featureMask forContacts:(NSSet *)contacts onCompletion:(void (^)(NSArray *unsupportedContacts))onCompletion {
    [FeatureMask checkFeatureMask:featureMask forContacts:contacts forceRefresh:NO onCompletion:onCompletion];
}

+ (void)checkFeatureMask:(NSInteger)featureMask forContacts:(NSSet *)contacts forceRefresh:(BOOL)forceRefresh onCompletion:(void (^)(NSArray *unsupportedContacts))onCompletion {
    NSSet *unsupportedContacts;
    if (forceRefresh) {
        unsupportedContacts = contacts;
    } else {
        unsupportedContacts = [FeatureMask filterContactsWithUnsupportedFeatureMask:featureMask fromContacts:contacts];
    }
    
    if ([unsupportedContacts count] == 0) {
        onCompletion(unsupportedContacts.allObjects);
        return;
    }

    __block MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    ContactStore *contactStore = [ContactStore sharedContactStore];
    [contactStore updateFeatureMasksForContacts:unsupportedContacts.allObjects contactSyncer:mediatorSyncableContacts onCompletion:^{
        [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
            if (error == nil) {
                // reread feature mask
                NSSet *unsupportedContacts2Run = [FeatureMask filterContactsWithUnsupportedFeatureMask:featureMask fromContacts:unsupportedContacts];

                onCompletion(unsupportedContacts2Run.allObjects);
            }
            else {
                // always run onCompletion
                onCompletion(unsupportedContacts.allObjects);
            }
        }];
    } onError:^(NSError * _Nonnull error) {
        // always run onCompletion
        onCompletion(unsupportedContacts.allObjects);
    }];
}

@end
