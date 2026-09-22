#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"

@class SetupConfiguration;

@protocol CompletedIDDelegate <NSObject>

// New method for coordinator flow - passes configuration
-(void)completedIDSetupWithConfiguration:(SetupConfiguration *)setupConfiguration;

@end

@interface CompletedIDViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet UIView *nickNameView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;

@property (weak, nonatomic) IBOutlet UIView *linkedToView;
@property (weak, nonatomic) IBOutlet UILabel *linkedToLabel;

@property (weak, nonatomic) IBOutlet UIView *syncContactsView;
@property (weak, nonatomic) IBOutlet UILabel *syncContactsLabel;

@property (weak, nonatomic) IBOutlet UIView *enableSafeView;
@property (weak, nonatomic) IBOutlet UILabel *enableSafeLabel;

@property (weak, nonatomic) IBOutlet UILabel *nicknameValue;
@property (weak, nonatomic) IBOutlet UILabel *emailValue;
@property (weak, nonatomic) IBOutlet UILabel *phoneValue;
@property (weak, nonatomic) IBOutlet UILabel *syncContactValue;
@property (weak, nonatomic) IBOutlet UILabel *enableSafeValue;

@property (weak, nonatomic) IBOutlet UIView *emailView;
@property (weak, nonatomic) IBOutlet UIView *phoneView;

@property (weak, nonatomic) IBOutlet UIButton *finishButton;

@property (weak, nonatomic) IBOutlet UIImageView *contactImageView;
@property (weak, nonatomic) IBOutlet UIImageView *phoneImageView;
@property (weak, nonatomic) IBOutlet UIImageView *mailImageView;

- (IBAction)finishAction:(id)sender;

/// Re-enables the "Finish" button and the wizard controls after a failed setup completion, so the
/// user can try again.
- (void)resetCompletionProcess;

@property (weak) id<CompletedIDDelegate> delegate;

@property (strong) SetupConfiguration *setupConfiguration;

@end
