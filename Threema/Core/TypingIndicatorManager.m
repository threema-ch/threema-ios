//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "TypingIndicatorManager.h"
#import "Conversation.h"
#import "EntityFetcher.h"
#import "AppDelegate.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation TypingIndicatorManager {
    dispatch_source_t resetTimer;
    dispatch_queue_t resetQueue;
}

+ (int) typingIndicatorResendInterval {
    return kTypingIndicatorResendInterval;
}

+ (int) typingIndicatorTypingPauseInterval {
    return kTypingIndicatorTypingPauseInterval;
}

+ (TypingIndicatorManager*)sharedInstance {
    static TypingIndicatorManager *sharedInstance;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[TypingIndicatorManager alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        resetQueue = dispatch_queue_create("ch.threema.resetQueue", 0);
        resetTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, resetQueue);
        dispatch_source_set_timer(resetTimer, dispatch_time(DISPATCH_TIME_NOW, kTypingIndicatorTimeout/2 * NSEC_PER_SEC),
                                  kTypingIndicatorTimeout/2 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(resetTimer, ^{
            [self resetTypingIndicators];
        });
        dispatch_resume(resetTimer);
    }
    return self;
}

- (void)resetTypingIndicators {
    DDLogVerbose(@"Resetting typing indicators");
    dispatch_async(dispatch_get_main_queue(), ^{
        /* Fetch all Conversations that are currently typing, and reset the typing
         indicator if it was received too long ago */
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performBlockAndWait:^{
            NSArray *conversations = [entityManager.entityFetcher allConversations];
            if (conversations == nil) {
                DDLogError(@"No conversations found");
                return;
            }
            
            [entityManager performSyncBlockAndSafe:^{
                for (Conversation *conversation in conversations) {
                    if (conversation.typing.boolValue && ((conversation.lastTypingStart != nil && [conversation.lastTypingStart timeIntervalSinceNow] < -kTypingIndicatorTimeout))) {
                        DDLogVerbose(@"Reset typing indicator on conversation with %@", conversation.contact.identity);
                        conversation.typing = [NSNumber numberWithBool:NO];
                    }
                }
            }];
        }];
    });
}

- (void)setTypingIndicatorForIdentity:(NSString*)identity typing:(BOOL)typing {
    dispatch_async(dispatch_get_main_queue(), ^{
        EntityManager *entityManager = [[EntityManager alloc] init];
        Conversation *conversation = [entityManager.entityFetcher conversationForIdentity:identity];
        if (conversation == nil) {
            DDLogInfo(@"No conversation with identity %@ found", identity);
            return;
        }
        
        conversation.typing = [NSNumber numberWithBool:typing];
    });
}

@end
