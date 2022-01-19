//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "ChatDeleteAction.h"

@interface ChatDeleteAction ()

@end

@implementation ChatDeleteAction

- (void)executeAction {
    
    NSArray *selectedRows = [self.chatViewController.chatContent indexPathsForSelectedRows];
    if (selectedRows.count > 0) {
        NSMutableArray *deletionArray = [NSMutableArray array];
        
        for (NSIndexPath *selectionIndex in selectedRows) {
            [deletionArray addObject:[self.chatViewController objectAtIndexPath:selectionIndex]];
        }
        
        [_entityManager performSyncBlockAndSafe:^{
            /* delete messages in CD and GUI */
            BOOL shouldUpdateLastMessage = false;
            for (NSObject *delobj in deletionArray) {
                if ([delobj isKindOfClass:[BaseMessage class]]) {
                    BaseMessage *m = (BaseMessage*)delobj;
                    if (m.id == self.chatViewController.conversation.lastMessage.id) {
                        shouldUpdateLastMessage = true;
                    }
                    
                    m.conversation = nil;
                    [[_entityManager entityDestroyer] deleteObjectWithObject:m];
                }
            }
            if (shouldUpdateLastMessage) {
                [self.chatViewController updateConversationLastMessage];
            }
        }];
    } else {
        // delete all messages of conversation
        (void)[[_entityManager entityDestroyer] deleteMessagesOfCoversation:self.chatViewController.conversation];
    }
    
    if (self.chatViewController.editing == YES) {
        self.chatViewController.editing = NO;
    }
    [self.chatViewController updateConversation];
    
}

@end
