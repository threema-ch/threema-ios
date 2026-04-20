#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"
#import "MoreView.h"
#import "Threema-Swift.h"

@interface LinkIDViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (weak, nonatomic) IBOutlet UIView *emailView;
@property (weak, nonatomic) IBOutlet UIView *emailBackgroundView;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UIImageView *emailStateImageView;

@property (weak, nonatomic) IBOutlet UIView *countryView;
@property (weak, nonatomic) IBOutlet UILabel *countryLabel;
@property (weak, nonatomic) IBOutlet UILabel *countryCodeLabel;

@property (weak, nonatomic) IBOutlet UIView *phoneView;
@property (weak, nonatomic) IBOutlet UIView *phoneBackroundView;
@property (weak, nonatomic) IBOutlet UITextField *phoneTextField;
@property (weak, nonatomic) IBOutlet UIImageView *phoneStateImageView;

@property (weak, nonatomic) IBOutlet UIView *countryPickerView;
@property (weak, nonatomic) IBOutlet UIPickerView *countryPicker;

@property (weak, nonatomic) IBOutlet UIImageView *phoneImageView;
@property (weak, nonatomic) IBOutlet UIImageView *mailImageView;

@property (weak, nonatomic) IBOutlet UIButton *selectedCountryButton;
- (IBAction)selectedCountryAction:(id)sender;

@property (strong, nonatomic) SetupConfiguration *setupConfiguration;

@end
