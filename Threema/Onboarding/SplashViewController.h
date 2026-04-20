#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"
#import "ZSWTappableLabel.h"

@class SetupConfiguration;

@protocol SplashViewControllerDelegate;

@interface SplashViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UIImageView *threemaLogoView;

@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (weak, nonatomic) IBOutlet UIView *privacyView;
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UILabel *welcomeLabel;
@property (weak, nonatomic) IBOutlet UIButton *setupButton;
@property (weak, nonatomic) IBOutlet UIButton *restoreButton;
@property (weak, nonatomic) IBOutlet ZSWTappableLabel *privacyPolicyInfo;
@property (weak, nonatomic) IBOutlet UILabel *setupTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *restoreTitleLabel;
@property (weak, nonatomic) id<SplashViewControllerDelegate> delegate;

- (IBAction)setupAction:(id)sender;
- (IBAction)restoreAction:(id)sender;

- (void)showRestoreIdentityViewController;

- (void)showPrivacyControls;
- (void)showRandomSeedViewController;
- (void)showRestoreSafeViewController:(BOOL)identityOnly;
- (void)showRestoreIdentityViewControllerWithBackupData:(NSString * _Nullable)backupData
                                               password:(NSString * _Nullable)password
                                                  error:(NSError * _Nullable)error;
- (void)showRestoreOptionDataViewController;
- (void)showRestoreOptionBackupViewController;
- (void)showIDBackupQuestion;
- (void)showIDExistsQuestion;
- (void)showRemoteSecretExistsQuestion;
- (void)showLoadingHUD;
- (void)hideLoadingHUD;
- (void)showIdentityCreationError:(NSError *_Nonnull)error;
- (void)setAcceptPrivacyPolicyValues:(AcceptPrivacyPolicyVariant)variant;
- (void)presentPageViewControllerWithSetupConfiguration:(SetupConfiguration *_Nonnull)setupConfiguration;

@end
