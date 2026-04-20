#ifndef QuotedMessageProtocol_h
#define QuotedMessageProtocol_h

@protocol QuotedMessageProtocol <NSObject>

@property (nonatomic, retain, nullable) NSData *quotedMessageId NS_SWIFT_NAME(quotedMessageID);

- (nullable NSData *)quotedBody;

@end

#endif /* QuotedMessageProtocol_h */
