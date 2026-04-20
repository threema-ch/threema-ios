#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"
#import "MoreView.h"
#import "Threema-Swift.h"

@interface SyncContactsViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (weak, nonatomic) IBOutlet UIView *syncContactsView;
@property (weak, nonatomic) IBOutlet UILabel *syncContactsLabel;
@property (weak, nonatomic) IBOutlet UISwitch *syncContactsSwitch;

- (IBAction)syncContactSwitchChanged:(id)sender;

@property (strong, nonatomic) SetupConfiguration *setupConfiguration;

@end
