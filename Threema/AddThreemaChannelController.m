//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2021 Threema GmbH
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

#import "AddThreemaChannelController.h"
#import "ContactStore.h"
#import "Contact.h"
#import "MessageSender.h"
#import "ChatViewControllerCache.h"

@implementation AddThreemaChannelController {
    NSMutableArray *initialMessages;
    NSDictionary *notificationInfo;
}

- (void)addThreemaChannel {
    // Check if the Threema channel has already been added to the contacts
    Contact *contact = [[ContactStore sharedContactStore] contactForIdentity:@"*THREEMA"];
    if (contact != nil) {
        // Contact exists; open chat
        [self showConversationForContact:contact];        
        return;
    }
    
    // Ask user if he wants to add the contact
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"threema_channel_intro", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {}]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self addContact];
    }]];
    [self.parentViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)addContact {
    // Add contact, open conversation and send initial messages
    [[ContactStore sharedContactStore] addContactWithIdentity:@"*THREEMA" verificationLevel:kVerificationLevelUnverified onCompletion:^(Contact *contact, BOOL alreadyExists) {
        notificationInfo = [self showConversationForContact:contact];
        
        [self createInitialMessages];
        [self dispatchNextInitialMessage];
    } onError:^(NSError *error) {
        
    }];
}

- (void)dispatchNextInitialMessage {
    if (initialMessages.count == 0)
        return;
    
    NSString *message = [initialMessages objectAtIndex:0];
    [initialMessages removeObjectAtIndex:0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Conversation *conversation = [ChatViewControllerCache getConversationForNotificationInfo:notificationInfo];
        if (conversation != nil) {
            [MessageSender sendMessage:message inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {}];
        }
        
        [self dispatchNextInitialMessage];
    });
}

- (void)createInitialMessages {
    initialMessages = [NSMutableArray array];
    
    // If the system language is not German, change channel language to English first
    if (![[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0] hasPrefix:@"de"]) {
        [initialMessages addObject:@"en"];
    }
    
    [initialMessages addObject:@"Start News"];
    [initialMessages addObject:@"Start iOS"];
    [initialMessages addObject:@"Info"];
}

- (NSDictionary*)showConversationForContact:(Contact*)contact {
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          contact, kKeyContact,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil userInfo:info];
    });
    
    return info;
}

@end
