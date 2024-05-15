//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#import "LinkIDViewController.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import "NBMetadataHelper.h"
#import "LinkIDCountryPickerRowView.h"
#import "RectUtil.h"
#import "PhoneNumberNormalizer.h"
#import "UIDefines.h"
#import "ThreemaUtilityObjC.h"
#import "IntroQuestionView.h"
#import "LicenseStore.h"
#import "MDMSetup.h"
#import "UIImage+ColoredImage.h"
#import "NibUtil.h"

#define COUNTRY_ROW_HEIGHT 44.0

@interface LinkIDViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate, IntroQuestionDelegate>

@property NBMetadataHelper *metaDataHelper;
@property NSArray *allPhoneMetadata;
@property NSDictionary *selectedPhoneMetadata;

@property NSArray *countryNames;

@property NSMutableDictionary *country2Region;

@property NSString *currentCountry;

@property MyIdentityStore *identityStore;

@property BOOL didShowEmailWarning;
@property BOOL didShowPhoneWarning;
@property BOOL didAckInputWarning;

@property CGFloat phoneViewYOffset;
@property CGFloat countryViewYOffset;
@property CGFloat emailViewYOffset;

@property IntroQuestionView *questionView;

@property BOOL restoredLinkedEmail;
@property BOOL restoredLinkedPhone;

@end

@implementation LinkIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _identityStore = [MyIdentityStore sharedMyIdentityStore];
    [self checkForRestoredLinkData];
    
    [self setup];

    [self setupCountrySelection];
    
    _phoneViewYOffset = _phoneView.frame.origin.y;
    _countryViewYOffset = _countryView.frame.origin.y;
    _emailViewYOffset = _emailView.frame.origin.y;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    _identityStore.createIDEmail = _emailTextField.text;
    
    if (_restoredLinkedPhone) {
        _identityStore.createIDPhone = _phoneTextField.text;
    } else {
        NSString *phoneNumber = [self fullPhoneNumber];
        if (phoneNumber) {
            _identityStore.createIDPhone = phoneNumber;
        } else {
            _identityStore.createIDPhone = nil;
        }
    }

    [self hideKeyboard];
}

- (void)checkForRestoredLinkData {
    if (_identityStore.linkedEmail.length > 0) {
        _restoredLinkedEmail = YES;
        _emailTextField.userInteractionEnabled = NO;
    }
    
    if (_identityStore.linkedMobileNo.length > 0) {
        _restoredLinkedPhone = YES;
        _phoneTextField.userInteractionEnabled = NO;
    }
}

- (NSString *)fullPhoneNumber {
    if (_phoneTextField.text.length > 0) {
        NSString *regionalPart = [_phoneTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        return [NSString stringWithFormat:@"%@ %@", _countryCodeLabel.text, regionalPart];
    }
    
    return nil;
}

- (void)hideKeyboard {
    [_emailTextField resignFirstResponder];
    [_phoneTextField resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateView];
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

- (NSString *)countryNameForRegion:(NSString *)region {
    id countryDictionaryInstance = [NSDictionary dictionaryWithObject:region forKey:NSLocaleCountryCode];
    NSString *identifier = [NSLocale localeIdentifierFromComponents:countryDictionaryInstance];
    NSString *country = [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:identifier];

    return country;
}

- (void)setupCountrySelection {
    NSMutableArray *countries = [NSMutableArray array];
    NSMutableArray *codes = [NSMutableArray array];
    _country2Region = [NSMutableDictionary dictionary];
    
    NBMetadataHelper *metadataHelper = [[NBMetadataHelper alloc] init];
    
    [[metadataHelper countryCodeToCountryNumberDictionary] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *countryName = [self countryNameForRegion:key];
        if (countryName) {
            [countries addObject:countryName];
            [codes addObject:obj];
            
            [_country2Region setObject:key forKey:countryName];
        }
    }];
    
    _countryNames = [countries sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    _countryPicker.dataSource = self;
    _countryPicker.delegate = self;
    
    if (_restoredLinkedPhone == NO) {
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCountry:)];
        [_countryView addGestureRecognizer:tapGesture];
        _countryView.userInteractionEnabled = YES;
        _countryView.isAccessibilityElement = YES;
        [_countryView setAccessibilityHint: [BundleUtil localizedStringForKey:@"tap_to_change"]];
        
        UITapGestureRecognizer *codeTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCountry:)];
        [_countryCodeLabel addGestureRecognizer:codeTapGesture];
        _countryCodeLabel.userInteractionEnabled = YES;
        _countryCodeLabel.isAccessibilityElement = YES;
        [_countryCodeLabel setAccessibilityHint: [BundleUtil localizedStringForKey:@"tap_to_change"]];
    }
    
    UITapGestureRecognizer *mainTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMainView:)];
    [self.mainContentView addGestureRecognizer:mainTapGesture];
}

- (void)adaptToSmallScreen {
    [super adaptToSmallScreen];
    
    CGFloat yOffset = -36.0;
    _descriptionLabel.frame = [RectUtil offsetRect:_descriptionLabel.frame byX:0.0 byY:yOffset];
    _emailView.frame = [RectUtil offsetRect:_emailView.frame byX:0.0 byY:yOffset];
    _phoneView.frame = [RectUtil offsetRect:_phoneView.frame byX:0.0 byY:yOffset];
    _countryView.frame = [RectUtil offsetRect:_countryView.frame byX:0.0 byY:yOffset];
    
    
    yOffset -= 32.0;
    _countryPickerView.frame = [RectUtil offsetRect:_countryPickerView.frame byX:0.0 byY:yOffset];
}

- (void)setup {
    _emailBackgroundView.layer.cornerRadius = 3;
    _phoneBackroundView.layer.cornerRadius = 3;

    _countryView.layer.cornerRadius = 3;
    _countryView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _countryView.layer.borderWidth = 0.5;
    
    _emailView.layer.cornerRadius = 3;
    _emailView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _emailView.layer.borderWidth = 0.5;

    _phoneView.layer.cornerRadius = 3;
    _phoneView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _phoneView.layer.borderWidth = 0.5;

    _selectedCountryButton.layer.cornerRadius = 3;
    [_selectedCountryButton setTitle:[BundleUtil localizedStringForKey:@"ok"] forState:UIControlStateNormal];

    NSString *emailPlaceholder = [BundleUtil localizedStringForKey:@"id_enter_email"];
    _emailTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:emailPlaceholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];

    _emailTextField.delegate = self;
    _emailTextField.accessibilityHint = [BundleUtil localizedStringForKey:@"Email"];

    _phoneTextField.delegate = self;
    _phoneTextField.accessibilityHint = [BundleUtil localizedStringForKey:@"phone number"];
    
    if ([LicenseStore requiresLicenseKey]) {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_link_description_work"];
    } else {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_link_description"];
    }
    
    self.moreView.mainView = self.mainContentView;
    if ([LicenseStore requiresLicenseKey]) {
        _titleLabel.text = [BundleUtil localizedStringForKey:@"id_link_title_work"];
        self.moreView.moreMessageText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"more_information_link_id_work"], [ThreemaAppObjc appName], [ThreemaAppObjc appName]];
    } else {
        _titleLabel.text = [BundleUtil localizedStringForKey:@"id_link_title"];
        self.moreView.moreMessageText = [BundleUtil localizedStringForKey:@"more_information_link_id"];
    }
    _titleLabel.accessibilityIdentifier = @"id_link_title";
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
    if ([mdmSetup readonlyProfile]) {
        _emailTextField.enabled = NO;
        _phoneTextField.enabled = NO;
    }
    
    _emailTextField.tintColor = Colors.primaryWizard;
    _phoneTextField.tintColor = Colors.primaryWizard;
    _selectedCountryButton.backgroundColor = Colors.primaryWizard;
    [_selectedCountryButton setTitleColor:Colors.textSetup forState:UIControlStateNormal];
    
    _phoneImageView.image = [[UIImage systemImageNamed:@"phone.fill"] imageWithTintColor:Colors.white];
    _mailImageView.image = [[UIImage systemImageNamed:@"envelope.fill"] imageWithTintColor:Colors.white];
}

- (void)updatePhonePlaceholder {
    PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
    
    NSString *region;
    if (_currentCountry) {
        region = [_country2Region objectForKey:_currentCountry];
    } else {
        region = [PhoneNumberNormalizer userRegion];
    }
    
    if (region) {
        [self updateUIWithRegion:region];

        NSString *examplePhone = [normalizer exampleRegionalPhoneNumberForRegion:region];
        if (examplePhone != nil) {
            NSString *placeholder = [NSString stringWithFormat:@"%@ %@", examplePhone, [BundleUtil localizedStringForKey:@"(optional)"]];
            _phoneTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];
        }
    }
}

- (void)updateUIWithRegion:(NSString *)region {
    if (region) {
        NSString *countryName = [self countryNameForRegion:region];
        _countryLabel.text = countryName;
        
        NSInteger row = [_countryNames indexOfObject:countryName];
        if (row != NSNotFound) {
            NSString *codeString = [self codeForCountry:countryName];
            _countryCodeLabel.text = codeString;
            _countryCodeLabel.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", [BundleUtil localizedStringForKey:@"country_code"], codeString];

            [_countryPicker selectRow:row inComponent:0 animated:NO];
        }
    }
}

- (void)updateView {
    /* linked e-mail */
    if (_restoredLinkedEmail) {
        // A linked email address was restored, but we don't know the actual address (linkedEmail will be "***@***").   
        _emailTextField.text = [BundleUtil localizedStringForKey:@"(linked)"];
    } else if (_identityStore.createIDEmail) {
        self.emailTextField.text = _identityStore.createIDEmail;
    }
    
    /* linked mobile number */
    if (_restoredLinkedPhone) {
        // A linked phone number was restored, but we don't know the actual number (linkedMobileNo will be "***").        
        _phoneTextField.text = [BundleUtil localizedStringForKey:@"(linked)"];
    } else if (_identityStore.createIDPhone) {
        NSString *phoneNumber = _identityStore.createIDPhone;
        
        PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
        NSString *region = [normalizer regionForPhoneNumber:phoneNumber];
        if (region) {
            [self updateUIWithRegion:region];
            
            NSString *regionalPart = [normalizer regionalPartForPhoneNumber:phoneNumber];
            
            _phoneTextField.text = regionalPart;
        }
    }

    [self updatePhonePlaceholder];
    
    [self hideEmailIfNeeded];
}

- (void)showCountrySelector {
    [self hideKeyboard];
    
    [self showMessageView:_countryPickerView];
}

- (void)hideCountrySelector {
    [self hideMessageView:_countryPickerView];
}

- (BOOL)isInputValid {
    [self hideKeyboard];
    
    if ([self.moreView isShown]) {
        return NO;
    }
    
    if (_countryPickerView.hidden == NO) {
        return NO;
    }
    
    if ([self hasInput] == NO && _didAckInputWarning == NO) {
        [self showAlert];
        return NO;
    }
    
    BOOL shouldPage = YES;
    if ([self validateEmail] == NO) {
        shouldPage = NO;
    }
    
    if ([self validatePhoneNumber] == NO) {
        shouldPage = NO;
    }

    return shouldPage;
}

- (BOOL)hasInput {
    if (_emailTextField.text.length > 0) {
        return YES;
    }

    if (_phoneTextField.text.length > 0) {
        return YES;
    }
    
    return NO;
}

- (BOOL)validateEmail {
    if (_restoredLinkedEmail) {
        return YES;
    }
    
    if (_emailTextField.text.length == 0) {
        _emailStateImageView.hidden = YES;
        return YES;
    }

    BOOL isValid = [ThreemaUtilityObjC isValidEmail:_emailTextField.text];
    if (isValid) {
        _emailStateImageView.hidden = YES;
        return YES;
    } else {
        _emailStateImageView.hidden = NO;
    }

    if (_didShowEmailWarning) {
        return YES;
    } else {
        _didShowEmailWarning = YES;
        return NO;
    }
}

- (BOOL)validatePhoneNumber {
    if (_restoredLinkedPhone) {
        return YES;
    }

    NSString *phone = [self fullPhoneNumber];
    
    if (phone == nil) {
        _phoneStateImageView.hidden = YES;
        return YES;
    }
    
    PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
    NSString *prettyMobileNo;
    NSString *mobileNo = [normalizer phoneNumberToE164:phone withDefaultRegion:[PhoneNumberNormalizer userRegion] prettyFormat:&prettyMobileNo];
    if (mobileNo) {
        _phoneStateImageView.hidden = YES;
        return YES;
    } else {
        _phoneStateImageView.hidden = NO;
    }
    
    if (_didShowPhoneWarning) {
        return YES;
    } else {
        _didShowPhoneWarning = YES;
        return NO;
    }
}


- (NSString *)codeForCountry:(NSString *)countryName {
    NSString *region = [_country2Region objectForKey:countryName];
    NBMetadataHelper *metadataHelper = [[NBMetadataHelper alloc] init];
    
    NSString *code = [[metadataHelper countryCodeToCountryNumberDictionary] objectForKey:region];
    return [NSString stringWithFormat:@"+%@", code];
}

- (void)hideAlert {
    [self hideMessageView:_questionView];
}

- (void)showAlert {
    [self hideKeyboard];
    
    if (_questionView == nil) {
        _questionView = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        if ([LicenseStore requiresLicenseKey]) {
            _questionView.questionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_link_no_input_work"], [ThreemaAppObjc appName]];
        } else {
            _questionView.questionLabel.text = [BundleUtil localizedStringForKey:@"id_link_no_input"];            
        }
        
        [_questionView.noButton setTitle:[BundleUtil localizedStringForKey:@"yes"] forState:UIControlStateNormal];
        [_questionView.yesButton setTitle:[BundleUtil localizedStringForKey:@"no"] forState:UIControlStateNormal];
        
        _questionView.delegate = self;
        _questionView.frame = [RectUtil rect:_questionView.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:_questionView];
    }
    
    [self showMessageView:_questionView];
}

- (void)hideEmailIfNeeded {
    _emailView.hidden = ![LicenseStore requiresLicenseKey];
}

#pragma mark - IntroQuestionViewDelegate

- (void)selectedYes:(IntroQuestionView *)sender {
    [self hideAlert];
    
    [_phoneTextField becomeFirstResponder];
}

- (void)selectedNo:(IntroQuestionView *)sender {
    _didAckInputWarning = YES;
    [self hideAlert];
    
    [self.containerDelegate pageLeft];
}

#pragma mark - UITapGestureRecognizer

- (void)tappedCountry:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self showCountrySelector];
    }
}

- (void)tappedMainView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideKeyboard];
    }
}

- (IBAction)selectedCountryAction:(id)sender {
    [self hideCountrySelector];
    
    NSInteger row = [_countryPicker selectedRowInComponent:0];
    NSString *name = [_countryNames objectAtIndex:row];

    _countryLabel.text = name;
    _currentCountry = name;
    _countryCodeLabel.text = [self codeForCountry:name];
    
    [self updatePhonePlaceholder];
}

#pragma mark - UIPickerViewDataSource, UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_countryNames count];
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    
    LinkIDCountryPickerRowView *rowView;
    if (view) {
        rowView = (LinkIDCountryPickerRowView *)view;
    } else {
        CGRect rect = CGRectMake(0.0, 0.0, _countryPicker.frame.size.width, COUNTRY_ROW_HEIGHT);
        rowView = [[LinkIDCountryPickerRowView alloc] initWithFrame:rect];
    }
    
    NSString *name = [_countryNames objectAtIndex:row];
    rowView.nameLabel.text = name;
    rowView.codeLabel.text = [self codeForCountry:name];

    return rowView;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];

    if (textField == _emailTextField && _didShowEmailWarning) {
        _emailTextField.text = newText;
        [self validateEmail];
        
        return NO;
    }

    if (textField == _phoneTextField && _didShowPhoneWarning) {
        _phoneTextField.text = newText;
        [self validatePhoneNumber];

        return NO;
    }

    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _emailTextField) {
        [_emailTextField resignFirstResponder];
        
        return NO;
    }
    
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

- (void)keyboardWillShow: (NSNotification *) notification {
    NSDictionary* info = [notification userInfo];
    CGRect keyboardRect = [[info objectForKey: UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardRectConverted = [self.view convertRect:keyboardRect fromView:nil];
    
    UIView *responderView;
    if (_emailTextField.isFirstResponder) {
        responderView = _emailView;
    } else if (_phoneTextField.isFirstResponder){
        responderView = _phoneView;
    } else {
        return;
    }
    _titleLabel.accessibilityLabel = [BundleUtil localizedStringForKey:@"Done"];
    
    
    CGFloat diff = CGRectGetMinY(keyboardRectConverted) - CGRectGetMaxY(responderView.frame) - 32.0;
    if (diff < 0.0) {
        if (_emailTextField.isFirstResponder) {
            _phoneView.hidden = YES;
            _countryView.hidden = YES;
        } else if (_phoneTextField.isFirstResponder){
            _emailView.hidden = YES;
            _countryView.hidden = YES;
        }

        NSTimeInterval animationDuration;
        UIViewAnimationOptions options = [ThreemaUtilityObjC animationOptionsFor:notification animationDuration:&animationDuration];
        
        [UIView animateWithDuration:animationDuration delay:0 options:options animations:^{
            
            responderView.frame = [RectUtil offsetRect:responderView.frame byX:0.0 byY:diff];
            
        } completion:^(BOOL finished) {}];
    }
}

- (void)keyboardWillHide:(NSNotification*)notification {
    NSTimeInterval animationDuration;
    UIViewAnimationOptions options = [ThreemaUtilityObjC animationOptionsFor:notification animationDuration:&animationDuration];
    
    _titleLabel.accessibilityLabel = _titleLabel.text;

    [UIView animateWithDuration:animationDuration delay:0 options:options animations:^{
        _phoneView.frame = [RectUtil setYPositionOf:_phoneView.frame y:_phoneViewYOffset];
        _countryView.frame = [RectUtil setYPositionOf:_countryView.frame y:_countryViewYOffset];
        _emailView.frame = [RectUtil setYPositionOf:_emailView.frame y:_emailViewYOffset];
    } completion:^(BOOL finished) {
        [self hideEmailIfNeeded];
        _countryView.hidden = NO;
        _phoneView.hidden = NO;
    }];
}

@end
