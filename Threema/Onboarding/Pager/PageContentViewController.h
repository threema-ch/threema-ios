#import <UIKit/UIKit.h>
#import "BundleUtil.h"

@protocol PageContentControllerDelegate <NSObject>

- (void)hideControls:(BOOL)hideControls;

- (void)pageRight;

- (void)pageLeft;

@end

@interface PageContentViewController : UIViewController

@property (weak) id<PageContentControllerDelegate> containerDelegate;

- (BOOL)isInputValid;

@end
