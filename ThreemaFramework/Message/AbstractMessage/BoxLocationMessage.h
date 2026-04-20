#import <ThreemaFramework/AbstractMessage.h>

@interface BoxLocationMessage : AbstractMessage <NSSecureCoding>

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double accuracy;
@property (nonatomic, strong) NSString *poiName;
@property (nonatomic, strong) NSString *poiAddress;

@end
