//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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

#import "RestoreIdentityViewController.h"
#import "UIDefines.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "MyIdentityStore.h"
#import "NSData+Base32.h"
#import "ScanBackupController.h"
#import "AppDelegate.h"
#import "IdentityBackupStore.h"
#import "ServerAPIConnector.h"
#import "UIImage+ColoredImage.h"
#import "RectUtil.h"
#import "IntroQuestionView.h"
#import "NibUtil.h"

@interface RestoreIdentityViewController () <IntroQuestionDelegate>

@end

@implementation RestoreIdentityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setup];
}

- (void)setup {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedScan:)];
    [_scanView addGestureRecognizer:tapGesture];
    _scanView.userInteractionEnabled = YES;
    _scanView.isAccessibilityElement = YES;
    [_scanView setAccessibilityHint: [BundleUtil localizedStringForKey:@"scan_id_backup"]];
    _scanLabel.text = [BundleUtil localizedStringForKey:@"scan_id_backup"];
    _scanLabel.textColor = Colors.primaryWizard;
    
    self.view.backgroundColor = [UIColor clearColor];

    _backupTextView.delegate = self;
    _passwordTextField.delegate = self;

    _textViewBackground.layer.cornerRadius = 3;

    _passwordView.layer.cornerRadius = 3;
    _passwordView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _passwordView.layer.borderWidth = 0.5;

    _passwordFieldBackground.layer.cornerRadius = 3;

    _scanView.layer.cornerRadius = 3;
    _scanView.layer.borderWidth = 1;
    _scanView.layer.borderColor = Colors.primaryWizard.CGColor;
    _scanView.isAccessibilityElement = YES;
    _scanView.accessibilityTraits = UIAccessibilityTraitButton;

    _doneButton.layer.cornerRadius = 3;
    
    _cancelButton.layer.borderWidth = 1;
    _cancelButton.layer.borderColor = Colors.primaryWizard.CGColor;
    _cancelButton.layer.cornerRadius = 3;
    
    [_doneButton setTitle:[BundleUtil localizedStringForKey:@"Done"] forState:UIControlStateNormal];
    [_cancelButton setTitle:[BundleUtil localizedStringForKey:@"Cancel"] forState:UIControlStateNormal];
    _doneButton.backgroundColor = Colors.primaryWizard;
    [_doneButton setTitleColor:Colors.textSetup forState:UIControlStateNormal];
    
    [_cancelButton setTitleColor:Colors.primaryWizard forState:UIControlStateNormal];
    
    NSString *placeholder = [BundleUtil localizedStringForKey:@"Password"];
    _passwordTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: THREEMA_COLOR_PLACEHOLDER}];

    _backupLabel.text = [BundleUtil localizedStringForKey:@"id_backup_placeholder"];
    _backupLabel.numberOfLines = 0;
    
    _titleLabel.text = [BundleUtil localizedStringForKey:@"restore_id_export"];
    _titleLabel.accessibilityIdentifier = @"restore_id_export";
    
    _scanImageView.image = [[UIImage systemImageNamed:@"qrcode.viewfinder"] imageWithTintColor:Colors.primaryWizard];
    
    _backupTextView.accessibilityIdentifier = @"backupTextView";
    
    _backupTextView.tintColor = Colors.primaryWizard;
    _passwordTextField.tintColor = Colors.primaryWizard;
        
    UITapGestureRecognizer *mainTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedMainView:)];
    [self.mainContentView addGestureRecognizer:mainTapGesture];
    
    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeAction:)];
    [self.view addGestureRecognizer:swipeGesture];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refreshView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateTextViewWithBackupCode];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self hideKeyboard];
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self refreshView];
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [_passwordTextField becomeFirstResponder];
        return NO;
    }
    
    NSCharacterSet *allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"];
    if (range.length == 0 && text.length > 0 && ![allowedCharacters characterIsMember:[text characterAtIndex:0]]) {
        return NO;
    }
    
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    //format text into (XXXX-XXXX-XXXX...)
    NSString *hyphen = @"-";
    NSString *rawText = [textView.text stringByReplacingOccurrencesOfString:hyphen withString:@""];

    if (rawText.length >= 4) {
        NSString *newText = @"";
        NSUInteger index = 0;
        
        while (rawText.length > index) {
            NSRange range = NSMakeRange(index, (rawText.length - index) > 4 ? 4 : rawText.length - index);
            NSString *n = [rawText substringWithRange:range];
            newText = [newText stringByAppendingString:n];
            if (range.length == 4 && (rawText.length - index) > 4) {
                newText = [newText stringByAppendingString:hyphen];
            }
            index += 4;
        }
        
        //calculate new cursor position
        NSRange cursorPos = textView.selectedRange;
        NSUInteger hyphenCount = [[textView.text componentsSeparatedByString:hyphen] count] - 1;
        if (cursorPos.location > (hyphenCount * 4)) {
            NSUInteger newHyphenCount = [[newText componentsSeparatedByString:hyphen] count] - 1;
            cursorPos.location += newHyphenCount - hyphenCount;
        }

        //update modified text and set cursor position
        textView.text = newText;
        textView.selectedRange = cursorPos;
    }
    
    _backupLabel.hidden = textView.text.length > 0 ? YES : NO;
    
    [self updateDoneEnabledWithPassword:_passwordTextField.text];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self refreshView];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self doneAction:nil];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self updateDoneEnabledWithPassword:newText];
    return YES;
}

- (IBAction)cancelAction:(id)sender {
    _passwordTextField.text = nil;
    if ([_delegate respondsToSelector:@selector(restoreIdentityCancelled)]) {
        [_delegate restoreIdentityCancelled];
    }
}

- (IBAction)doneAction:(id)sender {
    [self hideKeyboard];
    
    if (self.view != nil) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    MyIdentityStore *myIdentityStore = [MyIdentityStore sharedMyIdentityStore];
    [myIdentityStore restoreFromBackup:_backupTextView.text withPassword:_passwordTextField.text onCompletion:^{
        _passwordTextField.text = nil;
        ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
        /* Obtain server group from server */
        [apiConnector updateMyIdentityStore:myIdentityStore onCompletion:^{
            [myIdentityStore storeInKeychain];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
            });
            if ([_delegate respondsToSelector:@selector(restoreIdentityDone)]) {
                [_delegate restoreIdentityDone];
            }
        } onError:^(NSError *error) {
            [self handleError:error];
        }];
    } onError:^(NSError *error) {
        [self handleError:error];
    }];
}

- (void)showScanViewController {
    ScanBackupController *scanController = [[ScanBackupController alloc] init];
    scanController.containingViewController = self;
    scanController.delegate = self;
    [scanController startScan];
}

- (void)hideKeyboard {
    [_backupTextView resignFirstResponder];
    [_passwordTextField resignFirstResponder];
}

- (void)handleError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideKeyboard];
        
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        IntroQuestionView *view = (IntroQuestionView *)[NibUtil loadViewFromNibWithName:@"IntroQuestionView"];
        view.showOnlyOkButton = YES;
        view.questionLabel.text = error.localizedDescription;
        view.delegate = self;
        view.frame = [RectUtil rect:view.frame centerIn:self.view.frame round:YES];
        
        [self.view addSubview:view];
        
        [self showMessageView:view];
    });
}

- (void)updateTextViewWithBackupCode {
    if (_backupTextView.text.length == 0) {
        if ([AppDelegate sharedAppDelegate].urlRestoreData != nil) {
            /* put the dashes back in */
            _backupTextView.text = [[MyIdentityStore sharedMyIdentityStore] addBackupGroupDashes:[AppDelegate sharedAppDelegate].urlRestoreData];
            
            _backupLabel.hidden = YES;
            [_passwordTextField becomeFirstResponder];
        } else if (_backupData) {
            _backupTextView.text = [[MyIdentityStore sharedMyIdentityStore] addBackupGroupDashes:_backupData];
            
            _backupLabel.hidden = YES;
            
            if (_passwordData) {
                _passwordTextField.text = _passwordData;
            } else {
                [_passwordTextField becomeFirstResponder];
            }
        } else {
            [_backupTextView becomeFirstResponder];
        }
    }
    
    [self updateDoneEnabledWithPassword:_passwordTextField.text];
}

- (void)updateDoneEnabledWithPassword:(NSString*)password {
    /* enable done only if we have 50 bytes worth of Base32 data in backup data
     and a suitable password */
    
    BOOL enabled = YES;
    
    if (password.length < kMinimumPasswordLength) {
        enabled = NO;
    }
    
    if (![[MyIdentityStore sharedMyIdentityStore] isValidBackupFormat:_backupTextView.text]) {
        enabled = NO;
    }
    
    if (enabled) {
        _passwordTextField.enablesReturnKeyAutomatically = YES;
        _doneButton.userInteractionEnabled = YES;
        _doneButton.alpha = 1.0;
    } else {
        _passwordTextField.enablesReturnKeyAutomatically = NO;
        _doneButton.userInteractionEnabled = NO;
        _doneButton.alpha = 0.4;
    }
}

- (void) refreshView {
    _scanView.hidden = _backupTextView.isFirstResponder && [ScanBackupController canScan] ? NO : YES;
}

#pragma mark - IntroQuestionViewDelegate

- (void)selectedOk:(IntroQuestionView *)sender {
    [self hideMessageView:sender ignoreControls:YES];
    
    [_passwordTextField becomeFirstResponder];
}

#pragma mark Scan backup controller delegate

- (void)didScanBackup:(NSString *)backup {
    _backupLabel.hidden = YES;
    _backupTextView.text = backup;
}

#pragma mark - UITapGestureRecognizer

- (void)tappedScan:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self showScanViewController];
    }
}

- (void)tappedMainView:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self hideKeyboard];
    }
}

#pragma mark - UISwipeGestureRecognizer

- (void)swipeAction:(UISwipeGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if ([_delegate respondsToSelector:@selector(restoreIdentityCancelled)]) {
            [_delegate restoreIdentityCancelled];
        }
    }
}

@end
