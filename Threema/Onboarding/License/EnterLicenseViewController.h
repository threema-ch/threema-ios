#import <UIKit/UIKit.h>
#import "ProgressLabel.h"
#import "ZSWTappableLabel.h"

@protocol EnterLicenseDelegate <NSObject>

- (void)licenseConfirmed;

@end

@interface EnterLicenseViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIImageView *logoImageView;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIImageView *feedbackImageView;
@property (weak, nonatomic) IBOutlet UILabel *feedbackLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextField *licenseUsernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *licensePasswordTextField;
@property (weak, nonatomic) IBOutlet UITextField *serverTextField;
@property (weak, nonatomic) IBOutlet UILabel *threemaAdminInfoLabel;

@property (weak, nonatomic) IBOutlet UIButton *confirmButton;

@property (weak, nonatomic) IBOutlet UIImageView *keyImageView;

@property id<EnterLicenseDelegate> delegate;

@property BOOL doWorkApiFetch;

+ (EnterLicenseViewController*)instantiate;

- (IBAction)confirmAction:(id)sender;

- (void)showErrorMessage:(NSString *)errorMessage;

@end
