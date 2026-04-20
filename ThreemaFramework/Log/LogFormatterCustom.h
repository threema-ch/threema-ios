#import <Foundation/Foundation.h>
#import <ThreemaFramework/LogLevelCustom.h>
#import <stdatomic.h>

@import CocoaLumberjack;

@interface LogFormatterCustom : NSObject <DDLogFormatter> {
    atomic_int atomicLoggerCount;
    NSDateFormatter *threadUnsafeDateFormatter;
}
@end
