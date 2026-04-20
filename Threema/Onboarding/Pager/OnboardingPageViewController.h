#import <UIKit/UIKit.h>

@interface OnboardingPageViewController : UIViewController

@property (nonatomic) NSArray *viewControllers;

@property (weak, nonatomic) IBOutlet UIView *controlsView;

@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet UIButton *pageLeftButton;
@property (weak, nonatomic) IBOutlet UIButton *pageRightButton;

- (IBAction)pageLeftAction:(id)sender;
- (IBAction)pageRightAction:(id)sender;

@end
