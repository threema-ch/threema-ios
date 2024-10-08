//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#import "DeleteConversationAction.h"
#import "ContactStore.h"

#import "Threema-Swift.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface DeleteConversationAction ()

@property Conversation *conversation;
@property (copy) void (^onCompletion)(BOOL didCancel);

@end

@implementation DeleteConversationAction {
    Group *group;
    GroupManager *groupManager;
    EntityManager *entityManager;
}

+ (instancetype)deleteActionForConversation:(Conversation *)conversation {
    DeleteConversationAction *action = [[DeleteConversationAction alloc] init];
    action.conversation = conversation;
    return action;
}

- (void)executeOnCompletion:(void (^)(BOOL didCancel))onCompletion {
    _onCompletion  = onCompletion;

    entityManager = [[EntityManager alloc] init];
    groupManager = [[BusinessInjector new] groupManagerObjC];
    group = [groupManager getGroupWithConversation:_conversation];
    
    // If a group, ask for confirmation
    if (group) {
        [self presentAlertController];
    } else {
        [self deleteConversation];
        if (_onCompletion) {
            _onCompletion(YES);
        }
    }
}

- (NSString * _Nonnull)alertTitle {
    NSString *keyForTitle;

    if ([group isSelfMember]) {
        if ([group isOwnGroup]) {
            keyForTitle = @"group_dissolve_delete_sheet_title";
        }
        else {
            keyForTitle = @"group_leave_delete_sheet_title";
        }
    }
    else {
        keyForTitle = @"group_delete_sheet_title";
    }

    return [NSString stringWithFormat:[BundleUtil localizedStringForKey:keyForTitle], _conversation.groupName != nil ? _conversation.groupName : @""];
}

- (NSString * _Nonnull)alertMessage {
    NSString *keyForMessage;

    if ([group isSelfMember]) {
        if ([group isOwnGroup]) {
            keyForMessage = @"group_dissolve_delete_sheet_message";
        }
        else {
            keyForMessage = @"group_leave_delete_sheet_message";
        }
    }
    else {
        keyForMessage = @"group_delete_sheet_message";
    }

    return [BundleUtil localizedStringForKey:keyForMessage];
}

- (void)addActionButtons:(UIAlertController * _Nonnull)alertController {
    // duplicate of ConversationsViewControllerHelper
    // this code is called when managing groups via the groups list (Contacts tab)
    if ([group isSelfMember]) {
        if ([group isOwnGroup]) {
            [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"dissolve"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self dissolve];
                if (_onCompletion) {
                    _onCompletion(YES);
                }
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"group_dissolve_and_delete_button"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self dissolve]; 
                
                [self deleteConversation];
                if (_onCompletion) {
                    _onCompletion(YES);
                }
            }]];
        }
        else {
            [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"leave"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self leave];
                if (_onCompletion) {
                    _onCompletion(YES);
                }
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"group_leave_and_delete_button"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self leave]; 
                
                [self deleteConversation];
                if (_onCompletion) {
                    _onCompletion(YES);
                }
            }]];
        }
    }
    else {
        [alertController addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deleteConversation];
            if (_onCompletion) {
                _onCompletion(YES);
            }
        }]];
    }
}

- (void)presentAlertController {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self alertTitle] message:[self alertMessage] preferredStyle:UIAlertControllerStyleActionSheet];
    [self addActionButtons:alertController];

    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        if (_onCompletion) {
            _onCompletion(NO);
        }
    }];
    [alertController addAction:cancelAction];

    [_presentingViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)dissolve {
    if (group) {
        if ([group isOwnGroup]) {
            // Dissolve group, i'm creator and group is active
            [groupManager dissolveWithGroupID:group.groupID to:nil];
        }
    }
}

- (void)leave {
    if (group) {
        [groupManager leaveWithGroupID:group.groupID creator:group.groupCreatorIdentity toMembers:nil systemMessageDate:[NSDate date]];
    }
}

- (void)deleteConversation {
    if ([group state] == GroupStateActive || [group state] == GroupStateRequestedSync || _conversation == nil) {
        return;
    }
    
    [[MessageDraftStore shared] deleteDraftFor:_conversation];
    [[ChatScrollPosition _sharedObjC] removeSavedPositionFor:_conversation];

    // Delete conversation
    [entityManager performSyncBlockAndSafe:^{
        [[entityManager entityDestroyer] deleteWithConversation:_conversation];
    }];

    NotificationManager *notificationManager = [[NotificationManager alloc] init];
    [notificationManager updateUnreadMessagesCount];
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          _conversation, kKeyConversation,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeletedConversation object:nil userInfo:info];
}

@end
