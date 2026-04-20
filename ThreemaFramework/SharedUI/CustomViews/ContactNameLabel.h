#import <UIKit/UIKit.h>

@interface ContactNameLabel : UILabel

/// Type of `ContactEntity`
@property (nonatomic, strong) NSObject *contactObject;

/// @param contactObject Object of type `ContactEntity`
- (void)setContactObject:(NSObject *)contactObject;

@end
