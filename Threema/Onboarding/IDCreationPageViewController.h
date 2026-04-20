#import "ThreemaFramework.h"
#import "PageContentViewController.h"
#import "MoreView.h"

@interface IDCreationPageViewController : PageContentViewController

@property (weak, nonatomic) IBOutlet UIView *mainContentView;
@property (weak, nonatomic) IBOutlet MoreView *moreView;

@property NSString *moreMessageText;

- (void)showMessageView:(UIView *)messageView;

- (void)hideMessageView:(UIView *)messageView;
- (void)hideMessageView:(UIView *)messageView ignoreControls:(BOOL)ignoreControls;

- (void)adaptToSmallScreen;

@end
