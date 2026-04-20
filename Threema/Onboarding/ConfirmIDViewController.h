#import <UIKit/UIKit.h>
#import "IDCreationPageViewController.h"

@interface ConfirmIDViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *yourIdLabel;

@property (weak, nonatomic) IBOutlet UILabel *idLabel;

@end
