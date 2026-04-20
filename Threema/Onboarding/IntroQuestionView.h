#import <UIKit/UIKit.h>

@class IntroQuestionView;

@protocol IntroQuestionDelegate <NSObject>

@optional
- (void)selectedYes:(IntroQuestionView *)sender;

@optional
- (void)selectedNo:(IntroQuestionView *)sender;

@optional
- (void)selectedOk:(IntroQuestionView *)sender;

@end

@interface IntroQuestionView : UIView

@property BOOL showOnlyOkButton;

@property (nonatomic) NSString *title;

@property (weak, nonatomic) IBOutlet UILabel *questionTitle;
@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UIStackView *alertPane;
@property (weak, nonatomic) IBOutlet UIStackView *confirmPane;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *okButton;

@property id<IntroQuestionDelegate> delegate;

- (IBAction)yesAction:(id)sender;
- (IBAction)noAction:(id)sender;
- (IBAction)okAction:(id)sender;

@end
