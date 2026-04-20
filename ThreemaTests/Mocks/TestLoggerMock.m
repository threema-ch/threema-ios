#import <Foundation/Foundation.h>
#import "TestLoggerMock.h"

@implementation TestLoggerMock {
    DDLogMessage *testLogMessage;
}

- (DDLogMessage *)getTestLogMessage {
    return testLogMessage;
}

- (void)logMessage:(nonnull DDLogMessage *)logMessage {
    testLogMessage = logMessage;
}

@end
