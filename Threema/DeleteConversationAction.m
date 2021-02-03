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

#import "DeleteConversationAction.h"
#import "GroupProxy.h"
#import "EntityManager.h"
#import "NotificationManager.h"

@interface DeleteConversationAction ()

@property Conversation *conversation;
@property (copy) void (^onCompletion)(BOOL didCancel);

@end

@implementation DeleteConversationAction

+ (instancetype)deleteActionForConversation:(Conversation *)conversation {
    DeleteConversationAction *action = [[DeleteConversationAction alloc] init];
    action.conversation = conversation;
    
    return action;
}

- (void)executeOnCompletion:(void (^)(BOOL didCancel))onCompletion {
    _onCompletion  = onCompletion;
    
    /* If this was a group conversation with members, ask for confirmation */
    if (_conversation.groupId != nil && _conversation.members.count > 0) {
        [self presentAlertController];
    } else {
        [self deleteConversationInDB];
    }
}

- (NSString *)alertMessage {
    NSString *message;
    
    if (_conversation.isGroup && _conversation.contact == nil) {
        message = NSLocalizedString(@"group_admin_delete_confirm", nil);
    } else {
        message = NSLocalizedString(@"group_delete_confirm", nil);
    }
    
    return message;
}

- (void)presentAlertController {
    NSString *title = [self alertMessage];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"leave", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * __nonnull alertAction) {
        
        [self deleteConversationInDB];
    }];
    [alertController addAction:action];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        if (_onCompletion) {
            _onCompletion(NO);
        }
    }];
    [alertController addAction:cancelAction];
    
    [_presentingViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)deleteConversationInDB {
    if (_conversation == nil)
        return;
    
    if ([_conversation isGroup]) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:_conversation];
        [group adminDeleteGroup];
    }
    
    /* Remove from Core Data */
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        [[entityManager entityDestroyer] deleteObjectWithObject:_conversation];
    }];
    
    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          _conversation, kKeyConversation,
                          nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDeletedConversation object:nil userInfo:info];
    
    if (_onCompletion) {
        _onCompletion(YES);
    }
}

@end
