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

#import "BaseMessage+OLD_Accessibility.h"
#import "Conversation.h"
#import "Contact.h"
#import "BundleUtil.h"

#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation BaseMessage (AccessibilityUtil)

- (NSString *)accessibilityMessageSender {
    NSString *senderText;
    if (self.isOwn.boolValue) {
        senderText = [BundleUtil localizedStringForKey:@"me"];
    } else if ([self.conversation isGroup]) {
        if (self.sender != nil) {
            senderText = self.sender.displayName;
        }
    } else {
        senderText = self.conversation.displayName;
    }
    
    return senderText;
}

- (NSString *)accessibilityMessageStatus {
    NSString *status = @"";
    
    if ([self.conversation isGroup]) {
        return status;
    }
    
    switch (self.old_messageState) {
        case MESSAGE_STATE_SENDING:
            status = [BundleUtil localizedStringForKey:@"status_sending"];
            break;
            
        case MESSAGE_STATE_SENT:
            status = [BundleUtil localizedStringForKey:@"status_sent"];
            break;
            
        case MESSAGE_STATE_DELIVERED:
            status = [BundleUtil localizedStringForKey:@"status_delivered"];
            break;
            
        case MESSAGE_STATE_READ:
            status = [BundleUtil localizedStringForKey:@"status_read"];
            break;
            
        case MESSAGE_STATE_USER_ACK:
            status = [BundleUtil localizedStringForKey:@"status_acknowledged"];
            break;
            
        case MESSAGE_STATE_USER_DECLINED:
            status = [BundleUtil localizedStringForKey:@"status_declined"];
            break;
            
        case MESSAGE_STATE_FAILED:
            status = [BundleUtil localizedStringForKey:@"status_failed"];
            break;
            
        default:
            break;
    }
    
    return status;
}

@end
