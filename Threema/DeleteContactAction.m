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

#import "DeleteContactAction.h"
#import "EntityManager.h"
#import "UserSettings.h"
#import "AppDelegate.h"
#import "NotificationManager.h"
#import "ContactStore.h"

@interface DeleteContactAction ()

@property EntityManager *entityManager;
@property Contact *contact;
@property UIAlertController *alertController;
@property (copy) void (^onCompletion)(BOOL didCancel);
@property NSString *idToExclude;

@end

@implementation DeleteContactAction

+ (instancetype)deleteActionForContact:(Contact *)contact {
    DeleteContactAction *action = [[DeleteContactAction alloc] init];
    action.contact = contact;
    
    return action;
}

- (void)executeOnCompletion:(void (^)(BOOL didCancel))onCompletion {
    _onCompletion  = onCompletion;
    
    _entityManager = [[EntityManager alloc] init];

    /* Check that there are no more group conversations where this contact is a member. */
    NSArray *groups = [_entityManager.entityFetcher groupConversationsForContact:_contact];
    
    if ([groups count] > 0) {
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"delete_contact_group_exists_title", nil) message:NSLocalizedString(@"delete_contact_group_exists_message", nil) actionOk:^(UIAlertAction * _Nonnull okAction) {
            _onCompletion(NO);
        }];
        return;
    }
    
    /* any conversations for this contact? If so, prompt before delete */
    if (_contact.conversations.count > 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"delete_contact_warn_title", nil) message:NSLocalizedString(@"delete_contact_warn_message", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self deleteContactInDB];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
            if (_onCompletion) {
                _onCompletion(NO);
            }
        }]];
        [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:alertController animated:YES completion:nil];
    } else {
        [self deleteContactInDB];
    }
}


- (void)deleteContactInDB {
    __block BOOL contactWasLinked = NO;
    [_entityManager performSyncBlockAndSafe:^{
        _idToExclude = _contact.identity;
        
        if (_contact.cnContactId != nil) {
            contactWasLinked = YES;
        }
        
        [[_entityManager entityDestroyer] deleteObjectWithObject:_contact];
    }];
    
    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
    
    /* remove from blacklist, if present */
    if ([[UserSettings sharedUserSettings].blacklist containsObject:_idToExclude]) {
        NSMutableOrderedSet *blacklist = [NSMutableOrderedSet orderedSetWithOrderedSet:[UserSettings sharedUserSettings].blacklist];
        [blacklist removeObject:_idToExclude];
        [UserSettings sharedUserSettings].blacklist = blacklist;
    }
    
    /* remove from profile picture receiver list */
    if ([[UserSettings sharedUserSettings].profilePictureContactList containsObject:_idToExclude]) {
        NSMutableSet *profilePictureContactList = [NSMutableSet setWithArray:[UserSettings sharedUserSettings].profilePictureContactList];
        [profilePictureContactList removeObject:_idToExclude];
        [UserSettings sharedUserSettings].profilePictureContactList = profilePictureContactList.allObjects;
    }
    
    /* remove from profile picture request list */
    [[ContactStore sharedContactStore] removeProfilePictureRequest:_idToExclude];
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          _contact, kKeyContact,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeletedContact object:nil userInfo:info];
        
    if (contactWasLinked && ![[UserSettings sharedUserSettings].syncExclusionList containsObject:_idToExclude]) {
        /* ask the user if he wants to add this contact to the exclusion list */
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"exclude_deleted_id_title", nil) message:NSLocalizedString(@"exclude_deleted_id_message", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"no", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            NSMutableArray *exclusionList = [NSMutableArray arrayWithArray:[UserSettings sharedUserSettings].syncExclusionList];
            [exclusionList addObject:_idToExclude];
            [exclusionList sortUsingSelector:@selector(caseInsensitiveCompare:)];
            [UserSettings sharedUserSettings].syncExclusionList = exclusionList;
        }]];
        [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:alertController animated:YES completion:nil];
    }
    
    if (_onCompletion) {
        _onCompletion(YES);
    }
}

@end
