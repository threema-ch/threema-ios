#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"
#import "MoreView.h"
#import "Threema-Swift.h"

@interface PickNicknameViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (weak, nonatomic) IBOutlet UIView *nicknameView;
@property (weak, nonatomic) IBOutlet UIView *nicknameBackgroundView;
@property (weak, nonatomic) IBOutlet UITextField *nicknameTextfield;
@property (weak, nonatomic) IBOutlet UIImageView *contactImageView;

@property (strong, nonatomic) SetupConfiguration *setupConfiguration;

@end
