#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface MoreView : UIView

@property UIView *mainView;

@property (nonatomic, strong) NSString *moreButtonTitle;
@property NSString *moreMessageText;
@property UIButton *okButton;
@property BOOL centerMoreView;

- (BOOL)isShown;

- (void)toggle;

@end
