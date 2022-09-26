//
// Copyright 2011-2012 Kosher Penguin LLC
// Created by Adar Porat (https://github.com/aporat) on 1/16/2012.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//		http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "KKPasscodeViewController.h"
#import "KKKeychain.h"
#import "KKPasscodeSettingsViewController.h"
#import "KKPasscodeLock.h"
#import "BundleUtil.h"
#import "AppGroup.h"

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ThreemaFramework/ThreemaFramework-swift.h"

#define kkIsOnIOS7OrLater() ([[UIDevice currentDevice].systemVersion floatValue] >= 7.0)

@interface KKPasscodeViewController (Private)

- (UITextField*)passcodeTextField;
- (NSArray*)boxes;
- (UIView*)headerViewForTextField:(UITextField*)textField;
- (void)moveToNextTableView;
- (void)moveToPreviousTableView;
- (void)incrementFailedAttemptsLabel;

@end


@implementation KKPasscodeViewController

@synthesize delegate = _delegate;
@synthesize mode = _mode;

#pragma mark -
#pragma mark UIViewController

- (void)loadView
{
	[super loadView];
    
    if (kkIsOnIOS7OrLater())
        self.automaticallyAdjustsScrollViewInsets = NO;
	
	_enterPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    if (kkIsOnIOS7OrLater())
        _enterPasscodeTableView.contentInset = UIEdgeInsetsMake([self iOS7TableTopInset],
                                                                _enterPasscodeTableView.contentInset.left,
                                                                _enterPasscodeTableView.contentInset.bottom,
                                                                _enterPasscodeTableView.contentInset.right);
	_enterPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_enterPasscodeTableView.delegate = self;
	_enterPasscodeTableView.dataSource = self;
    _enterPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _enterPasscodeTableView.scrollEnabled = NO;
    _enterPasscodeTableView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_enterPasscodeTableView];
	
	_setPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    if (kkIsOnIOS7OrLater())
        _setPasscodeTableView.contentInset = UIEdgeInsetsMake([self iOS7TableTopInset],
                                                                _enterPasscodeTableView.contentInset.left,
                                                                _enterPasscodeTableView.contentInset.bottom,
                                                                _enterPasscodeTableView.contentInset.right);
	_setPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_setPasscodeTableView.delegate = self;
	_setPasscodeTableView.dataSource = self;
	_setPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _setPasscodeTableView.scrollEnabled = NO;
    _setPasscodeTableView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_setPasscodeTableView];
	
	_confirmPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    if (kkIsOnIOS7OrLater())
        _confirmPasscodeTableView.contentInset = UIEdgeInsetsMake([self iOS7TableTopInset],
                                                              _enterPasscodeTableView.contentInset.left,
                                                              _enterPasscodeTableView.contentInset.bottom,
                                                              _enterPasscodeTableView.contentInset.right);
	_confirmPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_confirmPasscodeTableView.delegate = self;
	_confirmPasscodeTableView.dataSource = self;
    _confirmPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _confirmPasscodeTableView.scrollEnabled = NO;
    _confirmPasscodeTableView.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_confirmPasscodeTableView];
    
    _shouldReleaseFirstResponser = NO;
    
    _failedAttemptsCount = [[AppGroup userDefaults] integerForKey:@"FailedCodeAttempts"];
    
    [self.view setBackgroundColor:Colors.backgroundView];
    [Colors updateWithNavigationBar:self.navigationController.navigationBar];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
    _passcodeLockOn = [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
	_eraseData = [[KKPasscodeLock sharedLock] eraseOption] && [[KKKeychain getStringForKey:@"erase_data_on"] isEqualToString:@"YES"];
    
	_enterPasscodeTextField = [[UITextField alloc] init];
    _enterPasscodeTextField.delegate = self;
    _enterPasscodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    _enterPasscodeTextField.secureTextEntry = YES;
	_enterPasscodeTextField.hidden = YES;
    
    _setPasscodeTextField = [[UITextField alloc] init];
    _setPasscodeTextField.delegate = self;
    _setPasscodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    _setPasscodeTextField.secureTextEntry = YES;
	_setPasscodeTextField.hidden = YES;
    
	_confirmPasscodeTextField = [[UITextField alloc] init];
    _confirmPasscodeTextField.delegate = self;
    _confirmPasscodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    _confirmPasscodeTextField.secureTextEntry = YES;
	_confirmPasscodeTextField.hidden = YES;
	
	_tableViews = [[NSMutableArray alloc] init];
	_textFields = [[NSMutableArray alloc] init];
	_boxes = [[NSMutableArray alloc] init];
	
    
    
    
    if (_mode == KKPasscodeModeSet) {
        self.navigationItem.title = KKPasscodeLockLocalizedString(@"Set Passcode", @"");
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancelButtonPressed:)];
    } else if (_mode == KKPasscodeModeChange) {
        self.navigationItem.title = KKPasscodeLockLocalizedString(@"Change Passcode", @"");
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancelButtonPressed:)];
        
    } else if (_mode == KKPasscodeModeDisabled) {
        self.navigationItem.title = KKPasscodeLockLocalizedString(@"Turn off Passcode", @"");
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancelButtonPressed:)];
        
    } else {
        self.navigationItem.title = KKPasscodeLockLocalizedString(@"Enter Passcode", @"");
    }
    
    
    
	if (_mode == KKPasscodeModeSet || _mode == KKPasscodeModeChange) {
		if (_passcodeLockOn) {
			_enterPasscodeTableView.tableHeaderView = [self headerViewForTextField:_enterPasscodeTextField];
			[_tableViews addObject:_enterPasscodeTableView];
			[_textFields addObject:_enterPasscodeTextField];
			[_boxes addObject:[self boxes]];
            UIView *boxesView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 74.0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)];
			boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            for (int i = 0; i < [[_boxes lastObject] count]; i++) {
				[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
			}
			[_enterPasscodeTableView.tableHeaderView addSubview:boxesView];
		}
		
		_setPasscodeTableView.tableHeaderView = [self headerViewForTextField:_setPasscodeTextField];
        
		[_tableViews addObject:_setPasscodeTableView];
		[_textFields addObject:_setPasscodeTextField];
		[_boxes addObject:[self boxes]];
		UIView *boxesView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 74.0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)];
		boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_setPasscodeTableView.tableHeaderView addSubview:boxesView];
		
		_confirmPasscodeTableView.tableHeaderView = [self headerViewForTextField:_confirmPasscodeTextField];
		[_tableViews addObject:_confirmPasscodeTableView];
		[_textFields addObject:_confirmPasscodeTextField];
		[_boxes addObject:[self boxes]];
		UIView *boxesConfirmView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 74.0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)];
        boxesConfirmView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesConfirmView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_confirmPasscodeTableView.tableHeaderView addSubview:boxesConfirmView];
	} else {
		_enterPasscodeTableView.tableHeaderView = [self headerViewForTextField:_enterPasscodeTextField];
		[_tableViews addObject:_enterPasscodeTableView];
		[_textFields addObject:_enterPasscodeTextField];
		[_boxes addObject:[self boxes]];
        UIView *boxesView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 74.0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)];
		boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_enterPasscodeTableView.tableHeaderView addSubview:boxesView];
	}
	
	[self.view addSubview:[_tableViews objectAtIndex:0]];
	
	for (int i = 1; i < [_tableViews count]; i++) {
		UITableView *tableView = [_tableViews objectAtIndex:i];
		tableView.frame = CGRectMake(tableView.frame.origin.x + self.view.bounds.size.width,
                                     tableView.frame.origin.y,
                                     tableView.frame.size.width,
                                     tableView.frame.size.height);
        if (kkIsOnIOS7OrLater())
            tableView.contentInset = UIEdgeInsetsMake([self iOS7TableTopInset],
                                                      tableView.contentInset.left,
                                                      tableView.contentInset.bottom,
                                                      tableView.contentInset.right);
		[self.view addSubview:tableView];
	}
	
	[[_textFields objectAtIndex:0] becomeFirstResponder];
	[[_tableViews objectAtIndex:0] reloadData];
	[[_textFields objectAtIndex:[_tableViews count] - 1] setReturnKeyType:UIReturnKeyDone];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		if ([_tableViews count] > 1) {
			[self moveToNextTableView];
			[self moveToPreviousTableView];
		} else {
			UITableView *tableView = [_tableViews objectAtIndex:0];
			tableView.frame = CGRectMake(tableView.frame.origin.x,
                                         tableView.frame.origin.y,
                                         self.view.bounds.size.width,
                                         self.view.bounds.size.height);
		}
	}
    if (_failedAttemptsCount > 0) {
        _failedAttemptsCount--;
        [self incrementFailedAttemptsLabel];
    }
}

// workaround for issue on iPad, first responder gets lost after rotation to landscape while in background
- (void)viewDidLayoutSubviews {
    [[_textFields objectAtIndex:_currentPanel] becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    _shouldReleaseFirstResponser = YES;
    [_enterPasscodeTextField resignFirstResponder];
    [_setPasscodeTextField resignFirstResponder];
    [_confirmPasscodeTextField resignFirstResponder];
}


#pragma mark -
#pragma mark Private methods


- (void)cancelButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)incrementFailedAttemptsLabel
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
	_enterPasscodeTextField.text = @"";
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_currentPanel] objectAtIndex:i] setImage:[self emptyBoxImage]];
	}
	
	_failedAttemptsCount += 1;
	if (_failedAttemptsCount == 1) {
		_failedAttemptsLabel.text = KKPasscodeLockLocalizedString(@"1 Failed Passcode Attempt", @"");
	} else {
		_failedAttemptsLabel.text = [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"%i Failed Passcode Attempts", @""), _failedAttemptsCount];
	}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	CGSize size = [_failedAttemptsLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:14.0]];
	_failedAttemptsLabel.frame = _failedAttemptsView.frame = CGRectMake((self.view.bounds.size.width - (size.width + 40.0)) / 2, 150, size.width + 40.0, size.height + 10.0);
#pragma clang diagnostic pop
	
	CAGradientLayer *gradient = [CAGradientLayer layer];
	gradient.frame = _failedAttemptsView.bounds;
	gradient.colors = [NSArray arrayWithObjects:
                       (id)[[UIColor colorWithRed:0.7 green:0.05 blue:0.05 alpha:1.0] CGColor],
                       (id)[[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0] CGColor], nil];
	[_failedAttemptsView.layer insertSublayer:gradient atIndex:0];
	_failedAttemptsView.layer.masksToBounds = YES;
	
	_failedAttemptsLabel.hidden = NO;
	_failedAttemptsView.hidden = NO;
	
	if (_failedAttemptsCount >= [[KKPasscodeLock sharedLock] attemptsAllowed]) {
		
		if (_eraseData) {
			if ([_delegate respondsToSelector:@selector(shouldEraseApplicationData:)]) {
				[_delegate shouldEraseApplicationData:self];
			}
		} else {
			if ([_delegate respondsToSelector:@selector(didPasscodeEnteredIncorrectly:)]) {
				[_delegate didPasscodeEnteredIncorrectly:self];
			}
            
            /* show "erase data" button to give user a chance to reset app if he forgets the passphrase */
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:KKPasscodeLockLocalizedString(@"Erase Data", @"") style:UIBarButtonItemStylePlain target:self action:@selector(eraseDataButtonPressed)];
		}
	} else {
        [[AppGroup userDefaults] setInteger:_failedAttemptsCount forKey:@"FailedCodeAttempts"];
        [[AppGroup userDefaults] synchronize];
    }
}

- (void)eraseDataButtonPressed {
    NSString *title = KKPasscodeLockLocalizedString(@"Erase all data and reset passcode", @"");
    NSString *cancel = NSLocalizedString(@"cancel", nil);
    NSString *erase = KKPasscodeLockLocalizedString(@"Erase Data", @"");

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *eraseAction = [UIAlertAction actionWithTitle:erase style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self eraseData];
    }];
    
    [alertController addAction:cancelAction];
    [alertController addAction:eraseAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)eraseData {
    if ([_delegate respondsToSelector:@selector(shouldEraseApplicationData:)]) {
        [_delegate shouldEraseApplicationData:self];
    }
}

- (void)moveToNextTableView
{
	_currentPanel += 1;
    
	UITableView *oldTableView = [_tableViews objectAtIndex:_currentPanel - 1];
	UITableView *newTableView = [_tableViews objectAtIndex:_currentPanel];
    
	newTableView.frame = CGRectMake(oldTableView.frame.origin.x + self.view.bounds.size.width,
                                    oldTableView.frame.origin.y,
                                    oldTableView.frame.size.width,
                                    oldTableView.frame.size.height);
	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_currentPanel] objectAtIndex:i] setImage:[self emptyBoxImage]];
	}
	
	[UIView beginAnimations:@"" context:nil];
	[UIView setAnimationDuration:0.25];
	oldTableView.frame = CGRectMake(oldTableView.frame.origin.x - self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	newTableView.frame = self.view.frame;
	[UIView commitAnimations];
	
	_shouldReleaseFirstResponser = YES;
	[[_textFields objectAtIndex:_currentPanel - 1] resignFirstResponder];
	_shouldReleaseFirstResponser = NO;
	[[_textFields objectAtIndex:_currentPanel] becomeFirstResponder];
}


- (void)moveToPreviousTableView
{
	_currentPanel -= 1;
    
	UITableView *oldTableView = [_tableViews objectAtIndex:_currentPanel + 1];
	UITableView *newTableView = [_tableViews objectAtIndex:_currentPanel];
	newTableView.frame = CGRectMake(oldTableView.frame.origin.x - self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_currentPanel] objectAtIndex:i] setImage:[self emptyBoxImage]];
	}
	
	[UIView beginAnimations:@"" context:nil];
	[UIView setAnimationDuration:0.25];
	oldTableView.frame = CGRectMake(oldTableView.frame.origin.x + self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	newTableView.frame = self.view.frame;
	[UIView commitAnimations];
	
    _shouldReleaseFirstResponser = YES;
	[[_textFields objectAtIndex:_currentPanel + 1] resignFirstResponder];
    _shouldReleaseFirstResponser = NO;
	[[_textFields objectAtIndex:_currentPanel] becomeFirstResponder];
}


- (void)nextDigitPressed
{
	UITextField* textField = [_textFields objectAtIndex:_currentPanel];
	
	if (![textField.text isEqualToString:@""]) {
		
		if (_mode == KKPasscodeModeSet) {
			if ([textField isEqual:_setPasscodeTextField]) {
				[self moveToNextTableView];
			} else if ([textField isEqual:_confirmPasscodeTextField]) {
				if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
					_confirmPasscodeTextField.text = @"";
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", @"");
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
					[self moveToPreviousTableView];
				} else {
					if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
						[KKKeychain setString:@"YES" forKey:@"passcode_on"];
					}
					
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
					
                    [self dismissViewControllerAnimated:YES completion:nil];
				}
			}
		} else if (_mode == KKPasscodeModeChange) {
			NSString* passcode = [KKKeychain getStringForKey:@"passcode"];
			if ([textField isEqual:_enterPasscodeTextField]) {
				if ([passcode isEqualToString:_enterPasscodeTextField.text]) {
					[self moveToNextTableView];
                    [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
                    [[AppGroup userDefaults] synchronize];
				} else {
					[self incrementFailedAttemptsLabel];
				}
			} else if ([textField isEqual:_setPasscodeTextField]) {
				if ([passcode isEqualToString:_setPasscodeTextField.text]) {
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Enter a different passcode. You cannot re-use the same passcode.", @"");
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
				} else {
					_passcodeConfirmationWarningLabel.text = @"";
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 146.0, self.view.bounds.size.width, 30.0);
					[self moveToNextTableView];
				}
			} else if ([textField isEqual:_confirmPasscodeTextField]) {
				if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
					_confirmPasscodeTextField.text = @"";
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", "");
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
					[self moveToPreviousTableView];
				} else {
					if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
						[KKKeychain setString:@"YES" forKey:@"passcode_on"];
					}
					
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
                    
                    [self dismissViewControllerAnimated:YES completion:nil];
				}
			}
		}
	}
}

- (void)validatePasscode:(UITextField*)textField
{
    if (_mode == KKPasscodeModeDisabled) {
        NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
        if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
            if ([KKKeychain setString:@"NO" forKey:@"passcode_on"]) {
                [KKKeychain setString:@"" forKey:@"passcode"];
            }
            
            if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
                [_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
            }
            
            [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
            [[AppGroup userDefaults] synchronize];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self incrementFailedAttemptsLabel];
        }
    } else if (_mode == KKPasscodeModeEnter) {
        NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
        if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [UIView beginAnimations:@"fadeIn" context:nil];
                [UIView setAnimationDelay:0.25];
                [UIView setAnimationDuration:0.5];
                
                [UIView commitAnimations];
            }
            [[KKPasscodeLock sharedLock] updateLastUnlockTime];
            if ([_delegate respondsToSelector:@selector(didPasscodeEnteredCorrectly:)]) {
                [_delegate performSelector:@selector(didPasscodeEnteredCorrectly:) withObject:self];
            }
            
            [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
            [[AppGroup userDefaults] synchronize];

            [self dismissViewControllerAnimated:YES completion:^{
                if ([_delegate respondsToSelector:@selector(didPasscodeViewDismiss:)]) {
                    [_delegate performSelector:@selector(didPasscodeViewDismiss:) withObject:self];
                }
            }];
        } else {
            [self performSelector:@selector(incrementFailedAttemptsLabel) withObject:nil afterDelay:0.5];
        }
    } else if (_mode == KKPasscodeModeChange) {
        NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
        if ([textField isEqual:_enterPasscodeTextField]) {
            if ([passcode isEqualToString:_enterPasscodeTextField.text]) {
                [[AppGroup userDefaults] setInteger:0 forKey:@"FailedCodeAttempts"];
                [[AppGroup userDefaults] synchronize];
                [self moveToNextTableView];
            } else {
                [self incrementFailedAttemptsLabel];
            }
        } else if ([textField isEqual:_setPasscodeTextField]) {
            if ([passcode isEqualToString:_setPasscodeTextField.text]) {
                _setPasscodeTextField.text = @"";
                for (int i = 0; i < kPasscodeBoxesCount; i++) {
                    [[[_boxes objectAtIndex:_currentPanel] objectAtIndex:i] setImage:[self emptyBoxImage]];
                }
                _passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Enter a different passcode. You cannot re-use the same passcode.", @"");
                _passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
            } else {
                _passcodeConfirmationWarningLabel.text = @"";
                _passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 146.0, self.view.bounds.size.width, 30.0);
                [self moveToNextTableView];
            }
        } else if ([textField isEqual:_confirmPasscodeTextField]) {
            if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
                _confirmPasscodeTextField.text = @"";
                _setPasscodeTextField.text = @"";
                _passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", @"");
                _passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
                [self moveToPreviousTableView];
            } else {
                if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
                    [KKKeychain setString:@"YES" forKey:@"passcode_on"];
                }
                
                if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
                    [_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
                }

                [self dismissViewControllerAnimated:YES completion:nil];
            }
        }
    } else if ([textField isEqual:_setPasscodeTextField]) {
        [self moveToNextTableView];
    } else if ([textField isEqual:_confirmPasscodeTextField]) {
        if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
            _confirmPasscodeTextField.text = @"";
            _setPasscodeTextField.text = @"";
            _passcodeConfirmationWarningLabel.text = KKPasscodeLockLocalizedString(@"Passcodes did not match. Try again.", @"");
            _passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 132.0, self.view.bounds.size.width, 60.0);
            [self moveToPreviousTableView];
        } else {
            if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
                [KKKeychain setString:@"YES" forKey:@"passcode_on"];
            }
            
            if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
                [_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
            }
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}


- (void)doneButtonPressed
{
	UITextField *textField = [_textFields objectAtIndex:_currentPanel];
	[self validatePasscode:textField];
}


- (UIView*)headerViewForTextField:(UITextField*)textField
{
    [self.view addSubview:textField];
	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, 70.0)];
	UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 28.0, self.view.bounds.size.width, 30.0)];
	headerLabel.backgroundColor = [UIColor clearColor];

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
	headerLabel.textAlignment = UITextAlignmentCenter;
#else
	headerLabel.textAlignment = NSTextAlignmentCenter;
#endif
        
	headerLabel.font = [UIFont boldSystemFontOfSize:17.0];
	headerLabel.shadowOffset = CGSizeMake(0, 1.0);
	
	if ([textField isEqual:_setPasscodeTextField]) {
		_passcodeConfirmationWarningLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 146.0, self.view.bounds.size.width, 30.0)];
		_passcodeConfirmationWarningLabel.textColor = headerLabel.textColor;
		_passcodeConfirmationWarningLabel.backgroundColor = [UIColor clearColor];
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
		_passcodeConfirmationWarningLabel.textAlignment = UITextAlignmentCenter;
#else
		_passcodeConfirmationWarningLabel.textAlignment = NSTextAlignmentCenter;
#endif

		_passcodeConfirmationWarningLabel.font = [UIFont systemFontOfSize:14.0];
		_passcodeConfirmationWarningLabel.shadowOffset = CGSizeMake(0, 1.0);
		_passcodeConfirmationWarningLabel.shadowColor = headerLabel.shadowColor;
		_passcodeConfirmationWarningLabel.text = @"";
		_passcodeConfirmationWarningLabel.numberOfLines = 0;
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
		_passcodeConfirmationWarningLabel.lineBreakMode = UILineBreakModeWordWrap;
#else
		_passcodeConfirmationWarningLabel.lineBreakMode = NSLineBreakByWordWrapping;
#endif
        
		[headerView addSubview:_passcodeConfirmationWarningLabel];
	}
	
	if ([textField isEqual:_enterPasscodeTextField]) {
		_failedAttemptsView = [[UIView alloc] init];
		_failedAttemptsLabel = [[UILabel alloc] init];
		_failedAttemptsLabel.backgroundColor = [UIColor clearColor];
		_failedAttemptsLabel.textColor = [UIColor whiteColor];
		_failedAttemptsLabel.text = @"";
		_failedAttemptsLabel.font = [UIFont boldSystemFontOfSize:14.0];
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
		_failedAttemptsLabel.textAlignment = UITextAlignmentCenter;
#else
		_failedAttemptsLabel.textAlignment = NSTextAlignmentCenter;
#endif
        
		_failedAttemptsLabel.shadowOffset = CGSizeMake(0, -1.0);
		_failedAttemptsLabel.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
		_failedAttemptsView.layer.cornerRadius = 14;
		_failedAttemptsView.layer.borderWidth = 1.0;
		_failedAttemptsView.layer.borderColor = [[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25] CGColor];
		
		_failedAttemptsLabel.hidden = YES;
		_failedAttemptsView.hidden = YES;
        
		_failedAttemptsView.layer.masksToBounds = YES;
        _failedAttemptsLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _failedAttemptsView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		
		[headerView addSubview:_failedAttemptsView];
		[headerView addSubview:_failedAttemptsLabel];
	}
	
	if (_mode == KKPasscodeModeSet) {
		if ([textField isEqual:_enterPasscodeTextField]) {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Enter your passcode", @"");
		} else if ([textField isEqual:_setPasscodeTextField]) {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Enter a passcode", @"");
		} else if ([textField isEqual:_confirmPasscodeTextField]) {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Re-enter your passcode", @"");
		}
	} else if (_mode == KKPasscodeModeDisabled) {
		headerLabel.text = KKPasscodeLockLocalizedString(@"Enter your passcode", @"");
	} else if (_mode == KKPasscodeModeChange) {
		if ([textField isEqual:_enterPasscodeTextField]) {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Enter your old passcode", @"");
		} else if ([textField isEqual:_setPasscodeTextField]) {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Enter your new passcode", @"");
		} else {
			headerLabel.text = KKPasscodeLockLocalizedString(@"Re-enter your new passcode", @"");
		}
	} else {
		headerLabel.text = KKPasscodeLockLocalizedString(@"Enter your passcode", @"");
	}
    
	headerLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
	[headerView addSubview:headerLabel];
	
	return headerView;
}


- (NSArray*)boxes
{
	NSMutableArray* squareViews = [NSMutableArray array];
	
	CGFloat squareX = 5.0;
    	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		UIImageView *square = [[UIImageView alloc] initWithImage:[self emptyBoxImage]];
		square.frame = CGRectMake(squareX, 0, kPasscodeBoxWidth, kPasscodeBoxHeight);
		[squareViews addObject:square];
		squareX += 71.0;
	}
	return [NSArray arrayWithArray:squareViews];
}

- (UIImage*)emptyBoxImage {
    static UIImage* emptyBoxImage;
    
    if (emptyBoxImage == nil) {
        emptyBoxImage =[BundleUtil imageNamed:@"KKPasscodeLock.bundle/box7_empty.png"];
    }
    
    return emptyBoxImage;
}

- (UIImage*)filledBoxImage {
    static UIImage* filledBoxImage;
    
    if (filledBoxImage == nil) {
        filledBoxImage =[BundleUtil imageNamed:@"KKPasscodeLock.bundle/box7_filled.png"];
    }
    
    return filledBoxImage;
}

- (CGFloat)iOS7TableTopInset {
    if ([UIScreen mainScreen].bounds.size.height > 667)
        return self.navigationController.navigationBar.frame.size.height+150;   /* iPhone 6 Plus */
    else if ([UIScreen mainScreen].bounds.size.height > 568)
        return self.navigationController.navigationBar.frame.size.height+130;   /* iPhone 6 */
    else if ([UIScreen mainScreen].bounds.size.height > 480)
        return self.navigationController.navigationBar.frame.size.height+60;    /* iPhone 5 */
    else
        return self.navigationController.navigationBar.frame.size.height+30;
}

#pragma mark -
#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
	return 0;
}


- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}


- (UITableViewCell*)tableView:(UITableView*)aTableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	static NSString* CellIdentifier = @"KKPasscodeViewControllerCell";
	
	UITableViewCell* cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	if ([aTableView isEqual:_enterPasscodeTableView]) {
		cell.accessoryView = _enterPasscodeTextField;
	} else if ([aTableView isEqual:_setPasscodeTableView]) {
		cell.accessoryView = _setPasscodeTextField;
	} else if ([aTableView isEqual:_confirmPasscodeTableView]) {
		cell.accessoryView = _confirmPasscodeTextField;
	}
	
	return cell;
}


#pragma mark -
#pragma mark UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
	if ([textField isEqual:[_textFields lastObject]]) {
		[self doneButtonPressed];
	} else {
		[self nextDigitPressed];
	}
	return NO;
}





- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string
{
    NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
    textField.text = result;
    
    for (int i = 0; i < kPasscodeBoxesCount; i++) {
        UIImageView *square = [[_boxes objectAtIndex:_currentPanel] objectAtIndex:i];
        if (i < [result length]) {
            square.image = [self filledBoxImage];
        } else {
            square.image = [self emptyBoxImage];
        }
    }
    
    if ([result length] == kPasscodeBoxesCount) {
        [self performSelector:@selector(validatePasscode:) withObject:textField afterDelay:0.1];
    }
    
    return NO;
}



- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    return _shouldReleaseFirstResponser;
}

#pragma mark -
#pragma mark Memory management


@end
