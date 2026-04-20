#import <ThreemaFramework/AbstractGroupMessage.h>

@interface GroupLocationMessage : AbstractGroupMessage <NSSecureCoding>

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double accuracy;
@property (nonatomic, strong) NSString *poiName;
@property (nonatomic, strong) NSString *poiAddress;

@end
