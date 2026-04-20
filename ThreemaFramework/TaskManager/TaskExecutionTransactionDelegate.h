@protocol TaskExecutionTransactionDelegate <NSObject>

- (void)transactionResponse:(uint8_t)messageType reason:(NSData * _Nullable)reason;

@end
