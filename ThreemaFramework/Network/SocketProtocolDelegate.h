@protocol SocketProtocolDelegate <NSObject>

- (void)didConnect;
- (void)didReadData:(nonnull NSData *)data tag:(int16_t)tag;
- (void)didDisconnectWithErrorCode:(NSInteger)code NS_SWIFT_NAME(didDisconnect(errorCode:));

@end
