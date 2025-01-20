//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2025 Threema GmbH
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


@interface EnterLicenseViewController () <UITextFieldDelegate>

@property LicenseStore *licenseStore;

@end

@implementation EnterLicenseViewController {
    BOOL isUsernameSetByMDM;
    BOOL isPasswordSetByMDM;
}

+ (EnterLicenseViewController*)instantiate {
    NSString *storyboardName = @"License";
    if ([LicenseStore isOnPrem]) {
        storyboardName = @"LicenseOnPrem";
    }

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    EnterLicenseViewController *viewController = [storyboard instantiateInitialViewController];
    // Set default value
    viewController.doWorkApiFetch = YES;
    return viewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    isUsernameSetByMDM = [mdmSetup existsMdmKey:MDM_KEY_LICENSE_USERNAME];
    isPasswordSetByMDM = [mdmSetup existsMdmKey:MDM_KEY_LICENSE_PASSWORD];

    _confirmButton.layer.cornerRadius = 3;
    _licenseUsernameTextField.layer.cornerRadius = 3;
    _licensePasswordTextField.layer.cornerRadius = 3;
    _serverTextField.layer.cornerRadius = 3;
   
    _feedbackLabel.textColor = [UIColor whiteColor];
    _feedbackLabel.numberOfLines = 5;
    
    _feedbackImageView.hidden = true;
    _feedbackLabel.hidden = true;
    _activityIndicatorView.hidden = true;
    
    _logoImageView.image = [Colors threemaLogo];
    _logoImageView.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    
    if ([ThreemaAppObjc current] == ThreemaAppOnPrem) {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"enter_license_onprem_description"];
        _threemaAdminInfoLabel.text = [BundleUtil localizedStringForKey:@"enter_license_onprem_admin_description"];
    } else {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"enter_license_description"];
        _threemaAdminInfoLabel.text = [BundleUtil localizedStringForKey:@"enter_license_work_admin_description"];
    }
    
    [_confirmButton setTitle:[BundleUtil localizedStringForKey:@"next"] forState:UIControlStateNormal];

    NSString *placeholder = [BundleUtil localizedStringForKey:@"enter_license_username_placeholder"];
    _licenseUsernameTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
    _licenseUsernameTextField.delegate = self;

    placeholder = [BundleUtil localizedStringForKey:@"enter_license_server_placeholder"];
    _serverTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
    _serverTextField.delegate = self;

    _licenseStore = [LicenseStore sharedLicenseStore];
    _licenseUsernameTextField.text = _licenseStore.licenseUsername;
    if (isUsernameSetByMDM == YES) {
        _licenseUsernameTextField.enabled = NO;
    }

    // Do not apply password if is set by MDM
    if (isPasswordSetByMDM == NO) {
        placeholder = [BundleUtil localizedStringForKey:@"enter_license_password_placeholder"];
        _licensePasswordTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
        _licensePasswordTextField.delegate = self;
        _licensePasswordTextField.enabled = YES;
        _licensePasswordTextField.text = _licenseStore.licensePassword;
    }
    else {
        placeholder = [BundleUtil localizedStringForKey:@"set_by_administrator"];
        _licensePasswordTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
        _licensePasswordTextField.enabled = NO;
    }
    _serverTextField.text = _licenseStore.onPremConfigUrl;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLicenseText) name:kNotificationLicenseMissing object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(confirmLicenseCheck) name:kNotificationLicenseCheckSuccess object:nil];
    
    UITapGestureRecognizer *mainTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMainView:)];
    mainTapGesture.cancelsTouchesInView = false;
    [self.view addGestureRecognizer:mainTapGesture];
       
    _confirmButton.backgroundColor = Colors.primaryWizard;
    [_confirmButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    _licenseUsernameTextField.tintColor = Colors.primaryWizard;
    _licensePasswordTextField.tintColor = Colors.primaryWizard;
    _serverTextField.tintColor = Colors.primaryWizard;
        
    // use other spacing for small screens
    if (self.view.frame.size.height < 500.0) {
        _stackView.spacing = 25.0;
    }
    
    UITapGestureRecognizer *feedbackImageViewRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedFeedbackImageView:)];
    feedbackImageViewRecognizer.numberOfTapsRequired = 2;
    _feedbackImageView.userInteractionEnabled = YES;
    [_feedbackImageView addGestureRecognizer:feedbackImageViewRecognizer];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateLicenseText {
    dispatch_async(dispatch_get_main_queue(), ^{
        _licenseUsernameTextField.text = _licenseStore.licenseUsername;
        // Do not apply password if is set by MDM
        if (isPasswordSetByMDM == NO) {
            _licensePasswordTextField.text = _licenseStore.licensePassword;
        }
        if ([LicenseStore isOnPrem]) {
            _serverTextField.text = _licenseStore.onPremConfigUrl;
        }
        if (_licenseStore.errorMessage && ![_licenseStore.errorMessage isEqualToString:@"License username/password too short"]) {
            [self hideKeyboard];
            [self showErrorMessage:_licenseStore.errorMessage];
            // disable button, user has to change key first
            _confirmButton.enabled = NO;
            _confirmButton.alpha = 0.7;
        }
    });
}

- (void)hideKeyboard {
    [_licenseUsernameTextField resignFirstResponder];
    [_licensePasswordTextField resignFirstResponder];
    [_serverTextField resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
       
    if (_serverTextField.text.length == 0) {
        _serverTextField.text = @"https://";
    }
    
    [_licenseUsernameTextField becomeFirstResponder];
    
    [self updateConfirmButton];
    [self updateColors];
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

- (void)updateColors {
    _licenseUsernameTextField.textColor = Colors.white;
    _licensePasswordTextField.textColor = Colors.white;
    _serverTextField.textColor = Colors.white;
    
    _licenseUsernameTextField.keyboardAppearance = UIKeyboardAppearanceDark;
    _licensePasswordTextField.keyboardAppearance = UIKeyboardAppearanceDark;
    _serverTextField.keyboardAppearance = UIKeyboardAppearanceDark;
}

- (void)updateConfirmButton {
    [self updateConfirmButtonUsername:_licenseUsernameTextField.text password:_licensePasswordTextField.text server:_serverTextField.text];
}

- (void)updateConfirmButtonUsername:(NSString*)username password:(NSString*)password server:(NSString*)server {
    if (username.length > 0 && (password.length > 0 || isPasswordSetByMDM) && (server == nil || server.length > 0)) {
        _confirmButton.enabled = YES;
        _confirmButton.alpha = 1.0;
    } else {
        _confirmButton.enabled = NO;
        _confirmButton.alpha = 0.7;
    }
    
    _confirmButton.hidden = NO;
}

- (void)showActivityIndicatorView:(BOOL)show {
    _activityIndicatorView.hidden = !show;
    if (show) {
        _feedbackImageView.hidden = true;
        [_activityIndicatorView startAnimating];
    } else {
        [_activityIndicatorView stopAnimating];
    }
}

- (void)showErrorMessage:(NSString *)errorMessage {
    [self showActivityIndicatorView:false];
        
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[Colors.white, Colors.red]];
    _feedbackImageView.image = [UIImage systemImageNamed:@"exclamationmark.circle.fill" withConfiguration:config];
    _feedbackImageView.hidden = false;
    
    _feedbackLabel.hidden = false;
    _feedbackLabel.text = errorMessage;
}

- (void)showSuccessMessage:(NSString *)successMessage {
    [self showActivityIndicatorView:false];
        
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[Colors.white, Colors.green]];
    _feedbackImageView.image = [UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config];
    _feedbackImageView.hidden = false;
    
    _feedbackLabel.text = successMessage;
}

- (void)showActivityIndicatorWithMessage:(NSString *)message {
    _feedbackLabel.text = message;
    _feedbackLabel.hidden = false;
    _confirmButton.hidden = true;
    
    [self showActivityIndicatorView:true];
}

#pragma mark - actions

- (IBAction)confirmAction:(id)sender {
    [self updateConfirmButton];
    if (!_confirmButton.enabled)
        return;
    
    [self showActivityIndicatorWithMessage:[BundleUtil localizedStringForKey:@"enter_license_checking"]];
    
    [self hideKeyboard];
    
    [_licenseStore setLicenseUsername:_licenseUsernameTextField.text];
    if (isPasswordSetByMDM == NO) {
        [_licenseStore setLicensePassword:_licensePasswordTextField.text];
    }

    if ([LicenseStore isOnPrem]) {
        [_licenseStore setOnPremConfigUrl:_serverTextField.text];
    }
    [_licenseStore performLicenseCheckWithCompletion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (_doWorkApiFetch == NO) {
                    [self confirmLicenseCheck];
                }
                else {
                    [WorkDataFetcher checkUpdateThreemaMDM:^{
                        [self confirmLicenseCheck];
                    } onError:^(NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showErrorMessage:[BundleUtil localizedStringForKey:@"work_data_fetch_failed_message"]];
                            _confirmButton.hidden = false;
                        });
                    }];
                }
            } else {
                [self showErrorMessage:_licenseStore.errorMessage];
                [self updateConfirmButton];
            }
        });
    }];
}

- (void)confirmLicenseCheck {
    dispatch_async(dispatch_get_main_queue(), ^{
        // While we was not conneted to the server, in background the notification extension could be started
        [AppGroup setActive:NO forType:AppGroupTypeNotificationExtension];
        [AppGroup setActive:NO forType:AppGroupTypeShareExtension];
        
        [self showSuccessMessage:[BundleUtil localizedStringForKey:@"ok"]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [_delegate licenseConfirmed];
        });
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (textField == _licenseUsernameTextField) {
        [self updateConfirmButtonUsername:newText password:_licensePasswordTextField.text server:_serverTextField.text];
    } else if (textField == _licensePasswordTextField) {
        [self updateConfirmButtonUsername:_licenseUsernameTextField.text password:newText server:_serverTextField.text];
    } else if (textField == _serverTextField) {
        [self updateConfirmButtonUsername:_licenseUsernameTextField.text password:_licensePasswordTextField.text server:newText];
    }
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _confirmButton.hidden = NO;
    _feedbackLabel.hidden = YES;
    _feedbackImageView.hidden = true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _licenseUsernameTextField) {
        [_licensePasswordTextField becomeFirstResponder];
        return NO;
    } else if (textField == _licensePasswordTextField && _serverTextField != nil) {
        [_serverTextField becomeFirstResponder];
        return NO;
    }
    
    [self updateConfirmButton];
    [self confirmAction:textField];
    return NO;
}

#pragma mark - UITapGestureRecognizer

- (void)tappedMainView:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideKeyboard];
    }
}

- (void)tappedFeedbackImageView:(UITapGestureRecognizer *)sender {
    NSString *title = [NSString stringWithFormat:@"%i", _licenseStore.error.code];
    NSString *message = [NSString stringWithFormat:@"%@", _licenseStore.error.description];
    [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:nil];
}

@end
