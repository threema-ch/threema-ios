//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "PickNicknameViewController.h"
#import "MyIdentityStore.h"
#import "RectUtil.h"
#import "UIDefines.h"
#import "ThreemaUtilityObjC.h"
#import "IntroQuestionView.h"
#import "MDMSetup.h"
#import "LicenseStore.h"
#import "ValidationLogger.h"
#import "UIImage+ColoredImage.h"
#import "NibUtil.h"

@interface PickNicknameViewController () <UITextFieldDelegate, IntroQuestionDelegate>

@property BOOL didShowNicknameAlert;
@property CGFloat nicknameViewYOffset;

@property IntroQuestionView *nicknameQuestionView;

@end

@implementation PickNicknameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setup];
    
    _nicknameViewYOffset = _nicknameView.frame.origin.y;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
 
    _nicknameQuestionView.hidden = YES;
    
    [self updateData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_nicknameTextfield resignFirstResponder];
    
    NSString *nickname = self.nicknameTextfield.text;
    [MyIdentityStore sharedMyIdentityStore].pushFromName = nickname;
    [[LicenseStore sharedLicenseStore] performUpdateWorkInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self registerForKeyboardNotifications];
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self unregisterForKeyboardNotifications];
}

- (void)updateData {
    if ([MyIdentityStore sharedMyIdentityStore].pushFromName != nil) {
        self.nicknameTextfield.text = [MyIdentityStore sharedMyIdentityStore].pushFromName;
    }
}

- (void)adaptToSmallScreen {
    [super adaptToSmallScreen];
    
    CGFloat yOffset = -16.0;
    _descriptionLabel.frame = [RectUtil offsetRect:_descriptionLabel.frame byX:0.0 byY:yOffset];

    yOffset = -48.0;
    _nicknameQuestionView.frame = [RectUtil offsetRect:_nicknameQuestionView.frame byX:0.0 byY:yOffset];
}

- (void)setup {
    _nicknameView.layer.cornerRadius = 3;
    _nicknameView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _nicknameView.layer.borderWidth = 0.5;

    _nicknameBackgroundView.layer.cornerRadius = 3;
    _nicknameBackgroundView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _nicknameBackgroundView.layer.borderWidth = 0.5;

    NSString *placeholder = [BundleUtil localizedStringForKey:@"id_enter_nickname"];
    _nicknameTextfield.placeholder = placeholder;
    _nicknameTextfield.delegate = self;
    [_nicknameTextfield setAccessibilityHint:[BundleUtil localizedStringForKey:@"id_completed_nickname"]];
    
    _titleLabel.text = [BundleUtil localizedStringForKey:@"id_pick_nickname_title"];
    
    if (TargetManagerObjc.isBusinessApp) {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_pick_nickname_description_work"];
    } else {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_pick_nickname_description"];
    }
    
    self.moreView.mainView = self.mainContentView;
    self.moreView.moreMessageText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"more_information_pick_nickname"], TargetManagerObjc.localizedAppName];

    UITapGestureRecognizer *mainTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMainView:)];
    [self.mainContentView addGestureRecognizer:mainTapGesture];
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    _nicknameTextfield.enabled = ![mdmSetup readonlyProfile];
    
    _nicknameTextfield.tintColor = UIColor.tintColor;
    
    _contactImageView.image = [UIImage systemImageNamed:@"person.fill"];
}

- (BOOL)isInputValid {
    if ([self.moreView isShown]) {
        return NO;
    }
    
    NSString *nickname = self.nicknameTextfield.text;
    if (nickname.length > 0 || _didShowNicknameAlert) {
        return YES;
    } else {
        [self showAlert];
        
        return NO;
    }
}

- (void)hideAlert {
    [self hideMessageView:_nicknameQuestionView];
}

- (void)showAlert {
    [_nicknameTextfield resignFirstResponder];
    
    if (_nicknameQuestionView == nil) {
        _nicknameQuestionView = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        _nicknameQuestionView.questionLabel.text =[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_pick_nickname_question"], TargetManagerObjc.localizedAppName];
        _nicknameQuestionView.delegate = self;
        _nicknameQuestionView.frame = [RectUtil rect:_nicknameQuestionView.frame centerIn:self.view.frame round:YES];

        [self.view addSubview:_nicknameQuestionView];
    }
    
    [_nicknameQuestionView.noButton setTitle:[BundleUtil localizedStringForKey:@"yes"] forState:UIControlStateNormal];
    [_nicknameQuestionView.yesButton setTitle:[BundleUtil localizedStringForKey:@"no"] forState:UIControlStateNormal];
    
    [self showMessageView:_nicknameQuestionView];
}

#pragma mark - IntroQuestionViewDelegate

- (void)selectedYes:(IntroQuestionView *)sender {
    [self hideAlert];

    [_nicknameTextfield becomeFirstResponder];
}

- (void)selectedNo:(IntroQuestionView *)sender {
    [self hideAlert];

    _didShowNicknameAlert = YES;
    NSString *placeholder = [MyIdentityStore sharedMyIdentityStore].identity;
    _nicknameTextfield.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
}

#pragma mark - UITapGestureRecognizer

- (void)tappedMainView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [_nicknameTextfield resignFirstResponder];
    }
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _nicknameTextfield) {
        [_nicknameTextfield resignFirstResponder];
        
        return NO;
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if ([newText lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > kPushFromNameLen)
        return NO;
    return YES;
}

# pragma mark Keyboard Notifications

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)keyboardWillShow: (NSNotification*) notification {
    NSDictionary* info = [notification userInfo];
    CGRect keyboardRect = [[info objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardRectConverted = [self.view convertRect:keyboardRect fromView:nil];
    
    CGFloat diff = CGRectGetMinY(keyboardRectConverted) - CGRectGetMaxY(_nicknameView.frame) - 32.0;
    if (diff < 0.0) {
        NSTimeInterval animationDuration;
        UIViewAnimationOptions options = [ThreemaUtilityObjC animationOptionsFor:notification animationDuration:&animationDuration];
        
        [UIView animateWithDuration:animationDuration delay:0 options:options animations:^{
            
            _nicknameView.frame = [RectUtil offsetRect:_nicknameView.frame byX:0.0 byY:diff];

        } completion:^(BOOL finished) {}];
    }
}

- (void)keyboardWillHide:(NSNotification*)aNotification {
    _nicknameView.frame = [RectUtil setYPositionOf:_nicknameView.frame y:_nicknameViewYOffset];
}

@end
