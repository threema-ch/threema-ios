typedef NS_CLOSED_ENUM(NSInteger, ConnectionState) {
    ConnectionStateDisconnected = 1,
    ConnectionStateConnecting,
    ConnectionStateConnected,
    ConnectionStateLoggedIn,
    ConnectionStateDisconnecting
};

@protocol ConnectionStateDelegate <NSObject>

/**
 Will be called when sever connection state has changed.

 @param state: Current connection state
 */
- (void)connectionStateChanged:(ConnectionState)state
    NS_SWIFT_NAME(changed(connectionState:));

@end
