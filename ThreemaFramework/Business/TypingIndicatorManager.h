#import <Foundation/Foundation.h>

#define kTypingIndicatorTimeout 60
#define kTypingIndicatorResendInterval 50
#define kTypingIndicatorTypingPauseInterval 15

@interface TypingIndicatorManager : NSObject

+ (int) typingIndicatorResendInterval;
+ (int) typingIndicatorTypingPauseInterval;

+ (TypingIndicatorManager*)sharedInstance;

- (void)resetTypingIndicators;
- (void)startObserving;
- (void)stopObserving;
- (void)setTypingIndicatorForIdentity:(NSString*)identity typing:(BOOL)typing;

@end
