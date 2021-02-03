//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "AbstractMessage.h"
#import "BoxTextMessage.h"
#import "GroupTextMessage.h"
#import "MessageQueue.h"
#import "BoxedMessage.h"
#import "ServerConnector.h"
#import "ProtocolDefines.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "ValidationLogger.h"
#import "MessageSender.h"
#import "DocumentManager.h"
#import "BackgroundTaskManagerProxy.h"
#import "NSString+Hex.h"
#import "AppGroup.h"
#import "GroupLeaveMessage.h"
#import "GroupRequestSyncMessage.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation MessageQueue {
    NSMutableArray *queue;
    dispatch_queue_t dispatchQueue;
}

+ (MessageQueue*)sharedMessageQueue {
    static MessageQueue *instance;
	
	@synchronized (self) {
		if (!instance)
			instance = [[MessageQueue alloc] init];
	}
	
	return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        queue = [NSMutableArray array];
        dispatchQueue = dispatch_queue_create("ch.threema.MessageQueue", NULL);
        
        /* register for connection status updates from ServerConnector */
        [[ServerConnector sharedServerConnector] addObserver:self forKeyPath:@"connectionState" options:0 context:nil];
        
        /* read from file now */
        [self loadFromFile];
    }
    return self;
}

- (void)enqueue:(AbstractMessage *)message {
    dispatch_async(dispatchQueue, ^{
        [self _enqueue:message async:YES];
    });
}

- (void)enqueueWait:(AbstractMessage *)message {
    dispatch_sync(dispatchQueue, ^{
        [self _enqueue:message async:NO];
    });
}

- (void)enqueueWaitForQuickReply:(AbstractMessage *)message {
    [self _enqueue:message async:NO];
}

- (void)_enqueue:(AbstractMessage*)message async:(BOOL)async {
    DDLogVerbose(@"Enqueue message %@", message);
    
    if (message == nil)
        return;
    
    if ([message.toIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogWarn(@"Drop message to myself");
        return;
    }
    
    if (message.isGroup == true && [message isKindOfClass:[AbstractGroupMessage class]]) {
        AbstractGroupMessage *groupMsg = (AbstractGroupMessage *)message;
        if ([groupMsg.groupCreator hasPrefix:@"*"] && [groupMsg.groupCreator isEqualToString:message.toIdentity] && ![message isKindOfClass:[GroupLeaveMessage class]] && ![message isKindOfClass:[GroupRequestSyncMessage class]]) {
            GroupProxy *proxy = [GroupProxy groupProxyForMessage:(AbstractGroupMessage *) message];
            if (proxy != nil) {
                if (![proxy.conversation.groupName hasPrefix:@"☁"]) {
                    DDLogWarn(@"Drop message to gateway id without store-incoming-message");
                    [MessageSender markMessageAsSent:message.messageId];
                    return;
                }
            }
        }
    }
        
    BoxedMessage *boxmsg = [message makeBox];
    if (boxmsg == nil)
        return;
            
    /* validation logging */
    if ([message isKindOfClass:[BoxTextMessage class]]) {
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:NO description:nil];
    } else if ([message isKindOfClass:[GroupTextMessage class]]) {
        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:NO description:nil];
    } else {
        [[ValidationLogger sharedValidationLogger] logSimpleMessage:message isIncoming:NO description:nil];
    }
    
    if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
        DDLogVerbose(@"Currently connected - sending message now");
        
        /* Only add to queue if we want an ACK for this message */
        if (!(boxmsg.flags & MESSAGE_FLAG_NOACK)) {
            [queue addObject:boxmsg];
            // do not use BackgroundTaskManagerProxy for share extension, because it's not available
            if ([AppGroup getCurrentType] == AppGroupTypeShareExtension) {
                [[ServerConnector sharedServerConnector] sendMessage:boxmsg];
            } else {
                [BackgroundTaskManagerProxy newBackgroundTaskWithKey:kAppSendingBackgroundTask timeout:10 completionHandler:^{
                    if (async == true) {
                        dispatch_async(dispatchQueue, ^{
                            [[ServerConnector sharedServerConnector] sendMessage:boxmsg];
                        });
                    } else {
                        dispatch_sync(dispatchQueue, ^{
                            [[ServerConnector sharedServerConnector] sendMessage:boxmsg];
                        });
                    }
                }];
            }
        } else {
            [[ServerConnector sharedServerConnector] sendMessage:boxmsg];
        }
    } else {
        if (boxmsg.flags & MESSAGE_FLAG_IMMEDIATE) {
            DDLogVerbose(@"Discarding immediate message because not connected");
        } else {
            [queue addObject:boxmsg];
        }
    }
}

- (void)processAck:(NSData*)messageId {
    /* check our queue for a message with this ID, and remove it */
    dispatch_async(dispatchQueue, ^{
        DDLogVerbose(@"Process ACK for message ID %@", messageId);
        
        for (BoxedMessage *message in queue) {
            if ([message.messageId isEqualToData:messageId]) {
                [queue removeObject:message];
                [MessageSender markMessageAsSent:messageId];
                if (queue.count == 0) {
                    [BackgroundTaskManagerProxy cancelBackgroundTaskWithKey:kAppSendingBackgroundTask];
                }
                return;
            }
        }
        
        DDLogWarn(@"Message ID %@ not found in queue", messageId);
    });
}

- (void)processQueue {
    DDLogInfo(@"Processing queue");
    for (BoxedMessage *message in queue) {
        [[ServerConnector sharedServerConnector] sendMessage:message];
    }
}

- (void)flush {
    DDLogInfo(@"Flushing queue");
    dispatch_async(dispatchQueue, ^{
        [queue removeAllObjects];
    });
}

- (void)loadFromFile {
    dispatch_sync(dispatchQueue, ^{
        NSString *savePath = self.savePath;
        if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
            
            DDLogInfo(@"Loading message queue from file");
            
            @try {
                NSArray *readQueue = [NSKeyedUnarchiver unarchiveObjectWithFile:self.savePath];
                if (readQueue != nil) {
                    NSString *myId = [MyIdentityStore sharedMyIdentityStore].identity;
                    int nread = 0;
                    
                    for (BoxedMessage *msg in readQueue) {
                        /* ensure this has the same from identity as we're currently using,
                           and ignore VoIP messages as they're likely to be old/stale anyway */
                        if ([myId isEqualToString:msg.fromIdentity] && !(msg.flags & MESSAGE_FLAG_VOIP)) {
                            [queue addObject:msg];
                            nread++;
                        }
                    }
                    
                    DDLogInfo(@"Read %d messages from queue file", nread);
                }
            }
            @catch (NSException *e) {
                /* file corrupted or whatever */
                DDLogError(@"Loading message queue failed: %@", e);
            }
            
            /* Delete queue file now. If something is bad with it that makes us crash, we 
               won't get stuck in a loop and the user will be able to relaunch. */
            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
            [self processQueue];
        }
    });
}

- (void)save {
    dispatch_async(dispatchQueue, ^{
        NSString *savePath = self.savePath;
        
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
        
        if (queue.count > 0) {
            DDLogInfo(@"Writing message queue to file (%lu entries)", (unsigned long)queue.count);
            
            [NSKeyedArchiver archiveRootObject:queue toFile:self.savePath];
        }
    });
}

- (NSString*)savePath {
    NSString *documentsDir = [DocumentManager documentsDirectory].path;
    
    return [documentsDir stringByAppendingPathComponent:@"MessageQueue"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [ServerConnector sharedServerConnector] && [keyPath isEqualToString:@"connectionState"]) {
        if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
            /* connection is now up - process queue */
            dispatch_async(dispatchQueue, ^{
                [self processQueue];
            });
        }
    }
}

@end
