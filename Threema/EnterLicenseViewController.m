//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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

#import "EnterLicenseViewController.h"
#import "LicenseStore.h"
#import "ServerConnector.h"
#import "BundleUtil.h"
#import "UIDefines.h"
#import "ServerAPIRequest.h"
#import "MDMSetup.h"
#import "UIImage+ColoredImage.h"
#import "WorkDataFetcher.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif


@interface EnterLicenseViewController () <UITextFieldDelegate, ZSWTappableLabelTapDelegate>

@property LicenseStore *licenseStore;

@end

@implementation EnterLicenseViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _confirmButton.layer.cornerRadius = 3;
    _licenseUsernameTextField.layer.cornerRadius = 3;
    _licensePasswordTextField.layer.cornerRadius = 3;
   
    _feedbackView.textColor = [UIColor whiteColor];
    _feedbackView.numberOfLines = 5;
    
    _descriptionLabel.text = [BundleUtil localizedStringForKey:@"enter_license_description"];
    [_confirmButton setTitle:[BundleUtil localizedStringForKey:@"next"] forState:UIControlStateNormal];

    NSString *placeholder = [BundleUtil localizedStringForKey:@"enter_license_username_placeholder"];
    _licenseUsernameTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
    _licenseUsernameTextField.delegate = self;
    
    placeholder = [BundleUtil localizedStringForKey:@"enter_license_password_placeholder"];
    _licensePasswordTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
    _licensePasswordTextField.delegate = self;

    _licenseStore = [LicenseStore sharedLicenseStore];
    _licenseUsernameTextField.text = _licenseStore.licenseUsername;
    _licensePasswordTextField.text = _licenseStore.licensePassword;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseText) name:kNotificationLicenseMissing object:nil];
    
    UITapGestureRecognizer *mainTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMainView:)];
    mainTapGesture.cancelsTouchesInView = false;
    [self.view addGestureRecognizer:mainTapGesture];
    
    self.threemaAppLinkLabel.font = [UIFont systemFontOfSize:16.0];
    self.threemaAppLinkLabel.tapDelegate = self;
    self.threemaAppLinkLabel.exclusiveTouch = true;
    NSDictionary *normalAttributes = @{NSFontAttributeName: _threemaAppLinkLabel.font, NSForegroundColorAttributeName: [UIColor whiteColor]};
    NSDictionary *linkAttributes = @{@"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                     @"ZSWTappableLabelHighlightedForegroundAttributeName": [Colors red],
                                     NSForegroundColorAttributeName: [Colors privacyPolicyLink],
                                     NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                                     @"NSTextCheckingResult": @1
                                     };
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:[BundleUtil localizedStringForKey:@"enter_license_info"] attributes:normalAttributes];
    [attributedString addAttributes:linkAttributes range:[[BundleUtil localizedStringForKey:@"enter_license_info"] rangeOfString:[BundleUtil localizedStringForKey:@"enter_license_info_link"]]];
    _threemaAppLinkLabel.attributedText = attributedString;
    
    _confirmButton.backgroundColor = [Colors mainThemeDark];
    [_confirmButton setTitleColor:[Colors fontNormal] forState:UIControlStateNormal];
    _licenseUsernameTextField.tintColor = [Colors mainThemeDark];
    _licensePasswordTextField.tintColor = [Colors mainThemeDark];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateLicenseText {
    dispatch_async(dispatch_get_main_queue(), ^{
        _licenseUsernameTextField.text = _licenseStore.licenseUsername;
        _licensePasswordTextField.text = _licenseStore.licensePassword;
        if (_licenseStore.errorMessage && ![_licenseStore.errorMessage isEqualToString:@"License username/password too short"]) {
            [_licenseUsernameTextField resignFirstResponder];
            [_licensePasswordTextField resignFirstResponder];
            _feedbackView.hidden = NO;
            _confirmButton.hidden = YES;
            [_feedbackView showErrorMessage:_licenseStore.errorMessage];
        }
    });
}

- (void)hideKeyboard {
    [_licenseUsernameTextField resignFirstResponder];
    [_licensePasswordTextField resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _keyImageView.image = [UIImage imageNamed:@"Key" inColor:[UIColor whiteColor]];
    
    [_licenseUsernameTextField becomeFirstResponder];
    
    [self updateConfirmButton];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)updateConfirmButton {
    [self updateConfirmButtonUsername:_licenseUsernameTextField.text password:_licensePasswordTextField.text];
}

- (void)updateConfirmButtonUsername:(NSString*)username password:(NSString*)password {
    if (username.length > 0 && password.length > 0) {
        _confirmButton.enabled = YES;
        _confirmButton.alpha = 1.0;
    } else {
        _confirmButton.enabled = NO;
        _confirmButton.alpha = 0.7;
    }
    
    _confirmButton.hidden = NO;
}

#pragma mark - actions

- (IBAction)confirmAction:(id)sender {
    [self updateConfirmButton];
    if (!_confirmButton.enabled)
        return;
    
    _feedbackView.hidden = NO;
    _confirmButton.hidden = YES;
    
    [_feedbackView showActivityIndicator];
    _feedbackView.text = [BundleUtil localizedStringForKey:@"enter_license_checking"];

    [_licenseUsernameTextField resignFirstResponder];
    [_licensePasswordTextField resignFirstResponder];
    
    [_licenseStore setLicenseUsername:_licenseUsernameTextField.text];
    [_licenseStore setLicensePassword:_licensePasswordTextField.text];
    [_licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [WorkDataFetcher checkUpdateThreemaMDM:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_feedbackView hideActivityIndicator];
                        
                        [_feedbackView showSuccessMessage:[BundleUtil localizedStringForKey:@"ok"]];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                            [_delegate licenseConfirmed];
                        });
                    });
                } onError:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_feedbackView hideActivityIndicator];
                        [_feedbackView showErrorMessage:_licenseStore.errorMessage];
                        
                        // disable button, user has to change key first
                        _confirmButton.enabled = NO;
                        _confirmButton.alpha = 0.7;
                    });
                }];
            } else {
                [_feedbackView hideActivityIndicator];
                [_feedbackView showErrorMessage:_licenseStore.errorMessage];
                
                // disable button, user has to change key first
                _confirmButton.enabled = NO;
                _confirmButton.alpha = 0.7;
            }
        });
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == _licenseUsernameTextField)
        [self updateConfirmButtonUsername:newText password:_licensePasswordTextField.text];
    else
        [self updateConfirmButtonUsername:_licenseUsernameTextField.text password:newText];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _confirmButton.hidden = NO;
    _feedbackView.hidden = YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _licenseUsernameTextField) {
        [_licensePasswordTextField becomeFirstResponder];
        return NO;
    }
    
    [self updateConfirmButton];
    [self confirmAction:textField];
    return NO;
}

#pragma mark - UITapGestureRecognizer

- (void)tappedMainView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideKeyboard];
    }
}

#pragma mark - ZSWTappableLabel delegate

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel tappedAtIndex:(NSInteger)idx withAttributes:(NSDictionary *)attributes {
    NSURL *appStoreUrl = [NSURL URLWithString:@"https://itunes.apple.com/app/id578665578"];
    if ([[UIApplication sharedApplication] canOpenURL:appStoreUrl]) {
        [[UIApplication sharedApplication] openURL:appStoreUrl options:@{} completionHandler:nil];
    }
}


@end
