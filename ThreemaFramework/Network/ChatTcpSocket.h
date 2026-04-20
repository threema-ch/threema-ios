#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "GCDAsyncSocket.h"

#ifndef ChatTcpSocket_h
#define ChatTcpSocket_h


#endif /* ChatTcpSocket_h */

@interface ChatTcpSocket : NSObject <SocketProtocol, GCDAsyncSocketDelegate>

@property (readonly) BOOL isIPv6;
@property (readonly) BOOL isProxyConnection;

@end
