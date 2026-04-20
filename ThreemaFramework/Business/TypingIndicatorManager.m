#import "TypingIndicatorManager.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation TypingIndicatorManager {
    dispatch_source_t resetTimer;
    dispatch_queue_t resetQueue;
    BOOL timerSuspended;
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

- (void)startObserving {
    if (!timerSuspended) {
        return;
    }
    
    dispatch_resume(resetTimer);
    timerSuspended = NO;
    DDLogVerbose(@"Typing indicator observing started");
}

- (void)stopObserving {
    if (timerSuspended) {
        return;
    }
    
    dispatch_suspend(resetTimer);
    timerSuspended = YES;
    DDLogVerbose(@"Typing indicator observing stopped");
}

- (void)resetTypingIndicators {
    DDLogVerbose(@"Resetting typing indicators");
    dispatch_async(dispatch_get_main_queue(), ^{
        /* Fetch all Conversations that are currently typing, and reset the typing
         indicator if it was received too long ago */
        EntityManager *entityManager = [[BusinessInjector ui] entityManager];
        [entityManager performAndWaitSave:^{
            NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:-kTypingIndicatorTimeout];
            NSArray *conversations = [entityManager.entityFetcher typingConversationEntitiesWithTimeoutDate:timeoutDate];
            
            if (conversations == nil) {
                return;
            }

            for (ConversationEntity *conversation in conversations) {
                DDLogVerbose(@"Reset typing indicator on conversation with %@", conversation.contact.identity);
                conversation.typing = @NO;
            }
        }];
    });
}

- (void)setTypingIndicatorForIdentity:(NSString*)identity typing:(BOOL)typing {
    DDLogInfo(@"Started setting typing indicator `%@` for conversation with contact identity %@.", typing ? @"ON" : @"OFF", identity);

    if (identity.length != ThreemaIdentityObjc.length) {
        DDLogError(@"Invalid contact identity: %@.", identity);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        EntityFetcher *entityFetcher = [[BusinessInjector ui] entityManager].entityFetcher;

        ConversationEntity *conversation = [entityFetcher conversationEntityFor:identity];
        if (conversation == nil) {
            DDLogError(@"No conversation found with contact identity %@.", identity);
            return;
        }

        conversation.typing = [NSNumber numberWithBool:typing];
        DDLogInfo(@"Typing indicator for conversation with contact identity %@ successfully set.", identity);
    });
}

@end
