//
//  JKLLockScreenPincodeView.h
//  JKLib
//
//  @date   2015. 03. 25.
//  @author Choi JoongKwan
//  @email  joongkwan.choi@gmail.com
//  @brief  Lock Screen Pin Code View (support to IB_DESIGNABLE)
//

#import <UIKit/UIKit.h>

@protocol JKLLockScreenPincodeViewDelegate;

IB_DESIGNABLE
@interface JKLLockScreenPincodeView : UIView

@property (nonatomic, weak) IBOutlet id<JKLLockScreenPincodeViewDelegate> delegate;
@property (nonatomic, strong) IBInspectable UIColor * pincodeColor;
@property (nonatomic, unsafe_unretained) IBInspectable BOOL enabled;
@property (nonatomic, assign) NSUInteger maxPincodeLength;

- (void)initPincode;
- (void)appendingPincode:(NSString *)pincode;
- (void)removeLastPincode;
- (void)wasCompleted;

@end


@protocol JKLLockScreenPincodeViewDelegate<NSObject>
@required
- (void)lockScreenPincodeView:(JKLLockScreenPincodeView *)lockScreenPincodeView pincode:(NSString *)pincode;
@end