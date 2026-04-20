@protocol MessageListenerDelegate <NSObject>

- (void)messageReceived:(_Nonnull id<MessageListenerDelegate>)listener type:(uint8_t)type data:(NSData * _Nonnull)data
    NS_SWIFT_NAME(messageReceived(listener:type:data:));

@end
