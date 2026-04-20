#import <Foundation/Foundation.h>

@import CocoaLumberjack;

@interface TestLoggerMock : DDAbstractLogger <DDLogger> {
}

- (DDLogMessage *)getTestLogMessage;

@end
