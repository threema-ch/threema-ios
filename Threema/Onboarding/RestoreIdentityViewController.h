#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"

@protocol RestoreIdentityViewControllerDelegate <NSObject>

-(void)restoreIdentityDone;
-(void)restoreIdentityCancelled;

@end

@interface RestoreIdentityViewController : IDCreationPageViewController <UITextViewDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIView *textViewBackground;
@property (weak, nonatomic) IBOutlet UITextView *backupTextView;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIView *passwordFieldBackground;
@property (weak, nonatomic) IBOutlet UILabel *backupLabel;

@property (weak) id<RestoreIdentityViewControllerDelegate> delegate;

@property (weak, nonatomic) IBOutlet UIView *scanView;
@property (weak, nonatomic) IBOutlet UILabel *scanLabel;
@property (weak, nonatomic) IBOutlet UIView *passwordView;
@property (weak, nonatomic) IBOutlet UIView *buttonsView;
@property (weak, nonatomic) IBOutlet UIImageView *scanImageView;

@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet UIImageView *keyImageView;

@property NSString *backupData;
@property NSString *passwordData;

- (IBAction)doneAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

- (void)setup;

- (void)handleError:(NSError *)error;
- (void)updateTextViewWithBackupCode;

@end
