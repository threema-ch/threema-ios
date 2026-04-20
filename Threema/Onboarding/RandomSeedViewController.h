#import <UIKit/UIKit.h>
#import "MoveFingerView.h"
#import "IDCreationPageViewController.h"
#import "MoreView.h"
#import "Threema-Swift.h"

@protocol RandomSeedViewControllerDelegate <NSObject>

- (void)generatedRandomSeed:(NSData *)seed;
- (void)cancelPressed;

@end


@interface RandomSeedViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *actionLabel;

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@property (weak, nonatomic) IBOutlet MoveFingerView *randomDataView;
@property (weak, nonatomic) IBOutlet UIView *randomDataBackground;
@property (weak, nonatomic) IBOutlet UIImageView *fingerView;
@property (weak, nonatomic) IBOutlet SetupButton *cancelButton;

@property (weak) id<RandomSeedViewControllerDelegate> delegate;

- (void)setup;

- (NSData *)getSeed;

@end
