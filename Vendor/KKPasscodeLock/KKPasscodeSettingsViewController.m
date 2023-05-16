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

#import "KKPasscodeSettingsViewController.h"
#import "KKKeychain.h"
#import "KKPasscodeViewController.h"
#import "KKPasscodeLock.h"
#import "KKPasscodeGracePeriodViewController.h"
#import "ModalNavigationController.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"
#import <LocalAuthentication/LocalAuthentication.h>


@implementation KKPasscodeSettingsViewController


@synthesize delegate = _delegate;

#pragma mark -
#pragma mark UIViewController methods

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = KKPasscodeLockLocalizedString(@"Passcode Lock", @"");
    
	_eraseDataSwitch = [[UISwitch alloc] init];
    [_eraseDataSwitch addTarget:self action:@selector(eraseDataSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    _eraseDataSwitch.accessibilityIdentifier = @"KKPasscodeSettingsViewControllerEraseDataSwitch";

    _touchIdSwitch = [[UISwitch alloc] init];
    [_touchIdSwitch addTarget:self action:@selector(touchIdSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
}

- (void)viewDidUnload
{
    _eraseDataSwitch = nil;
    _touchIdSwitch = nil;
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
    [self readSettings];
    
    [self.tableView reloadData];
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate {
    if (SYSTEM_IS_IPAD) {
        return YES;
    }
    return YES;
}


- (void)eraseOn {
    _eraseDataOn = YES;
    [KKKeychain setString:@"YES" forKey:@"erase_data_on"];

    [_eraseDataSwitch setOn:_eraseDataOn animated:YES];
}

- (void)eraseOff {
    _eraseDataOn = NO;
    [KKKeychain setString:@"NO" forKey:@"erase_data_on"];

    [_eraseDataSwitch setOn:_eraseDataOn animated:YES];
}

- (void)eraseDataSwitchChanged:(id)sender
{
	if (_eraseDataSwitch.on) {
		NSString* title = [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"All data in this app will be erased after %d failed passcode attempts.", @""), [[KKPasscodeLock sharedLock] attemptsAllowed]];
        
        NSString* cancel = KKPasscodeLockLocalizedString(@"Cancel", @"");
        NSString* erase = KKPasscodeLockLocalizedString(@"Enable", @"");
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self eraseOff];
        }];
        
        UIAlertAction *enableAction = [UIAlertAction actionWithTitle:erase style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self eraseOn];
        }];
        
        [alertController addAction:cancelAction];
        [alertController addAction:enableAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
	} else {
		_eraseDataOn = NO;
		[KKKeychain setString:@"NO" forKey:@"erase_data_on"];
	}
}

- (void)touchIdSwitchChanged:(id)sender
{
    if (_touchIdSwitch.on) {
        _touchIdOn = YES;
        [KKKeychain setString:@"YES" forKey:@"touch_id_on"];
    } else {
        _touchIdOn = NO;
        [KKKeychain setString:@"NO" forKey:@"touch_id_on"];
    }
}

- (NSString *)touchIdType {
    LAContext *context = [LAContext new];
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
        BOOL haveFaceId = NO;
        if (@available(iOS 11.0, *)) {
            if (context.biometryType == LABiometryTypeFaceID) {
                haveFaceId = YES;
            }
        }
        
        if (haveFaceId) {
            return @"Face ID";
        } else {
            return @"Touch ID";
        }
    } else {
        return nil;
    }
}

#pragma mark -
#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if ([[KKPasscodeLock sharedLock] eraseOption]) {
		return 4;
	}
	
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 2;
    else
        return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return KKPasscodeLockLocalizedString(@"The app passcode lock protects your data against prying eyes, but it is not a replacement for setting a passcode lock on your device.\nIf you haven't done so already, set a device passcode lock too in order to ensure that the data on your device is encrypted.", @"");
    }
	else if (section == 3) {
		return [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"Erase all content in the app after %d failed passcode attempts.", @""), [[KKPasscodeLock sharedLock] attemptsAllowed]];;
	} else {
		return @"";
	}
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	static NSString *CellIdentifier = @"KKPasscodeSettingsCell";
	static NSString *CellIdentifier2 = @"KKPasscodeSettingsCell2";
	
	UITableViewCell *cell;
    
    if (indexPath.section == 1) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier2];
        if (cell == nil)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier2];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
    cell.textLabel.textAlignment = UITextAlignmentLeft;
#else
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
#endif
    
    cell.textLabel.textColor = [UIColor blackColor];
	
	if (indexPath.section == 0) {
        
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
        cell.textLabel.textAlignment = UITextAlignmentCenter;
#else
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
#endif
        
        cell.textLabel.textColor = [UIColor colorWithRed:0 green:122.0f/255.0f blue:1.0f alpha:1.0f];
        
        if (indexPath.row == 0) {
            if (_passcodeLockOn) {
                cell.textLabel.text = KKPasscodeLockLocalizedString(@"Turn Passcode Off", @"");
            } else {
                cell.textLabel.text = KKPasscodeLockLocalizedString(@"Turn Passcode On", @"");
            }
            
            cell.accessibilityTraits = UIAccessibilityTraitButton;
        } else {
            cell.textLabel.text = KKPasscodeLockLocalizedString(@"Change Passcode", @"");
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            if (!_passcodeLockOn) {
                cell.accessibilityTraits = UIAccessibilityTraitNotEnabled;
                cell.textLabel.textColor = [UIColor grayColor];
            }
        }
	} else if (indexPath.section == 1) {
        
        cell.textLabel.text = KKPasscodeLockLocalizedString(@"Require Passcode", @"");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.accessibilityIdentifier = @"Identifier2";
        cell.detailTextLabel.text = [KKPasscodeSettingsViewController textForGracePeriod:_gracePeriod shortForm:YES];
        
	} else if (indexPath.section == 2) {
        BOOL touchIdSupported = YES;
        NSString *touchIdType = [self touchIdType];
        if (touchIdType == nil) {
            touchIdSupported = NO;
            touchIdType = @"Touch ID";  // for grayed out label
        }
        
        cell.accessoryView = _touchIdSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = touchIdType;
        if (_passcodeLockOn && touchIdSupported) {
            cell.textLabel.textColor = [UIColor blackColor];
            _touchIdSwitch.enabled = YES;
            cell.accessibilityTraits = UIAccessibilityTraitNone;
        } else {
            cell.textLabel.textColor = [UIColor grayColor];
            _touchIdSwitch.enabled = NO;
            cell.accessibilityTraits = UIAccessibilityTraitNotEnabled;
        }
    } else if (indexPath.section == 3) {
        cell.textLabel.text = KKPasscodeLockLocalizedString(@"Erase Data", @"");
        cell.accessoryView = _eraseDataSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (_passcodeLockOn) {
            cell.textLabel.textColor = [UIColor blackColor];
            _eraseDataSwitch.enabled = YES;
            cell.accessibilityTraits = UIAccessibilityTraitNone;
        } else {
            cell.textLabel.textColor = [UIColor grayColor];
            _eraseDataSwitch.enabled = NO;
            cell.accessibilityTraits = UIAccessibilityTraitNotEnabled;
        }
    }
	
	return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	if (indexPath.section == 0 && indexPath.row == 0) {
        if (!_passcodeLockOn) {
            NSString *title = KKPasscodeLockLocalizedString(@"Passcode lock notice", @"");
            NSString *message = KKPasscodeLockLocalizedString(@"ResetInfo", @"");
            NSString *cancel = NSLocalizedString(@"cancel", nil);
            NSString *ok = NSLocalizedString(@"ok", nil);
                
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self cancelAction];
            }];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:ok style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self okAction];
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:okAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
        } else {
            NSString *title = KKPasscodeLockLocalizedString(@"Passcode_remove_title", @"");
            NSString *message = KKPasscodeLockLocalizedString(@"Passcode_remove_message", @"");
            NSString *cancel = NSLocalizedString(@"cancel", nil);
                
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self cancelAction];
            }];
            
            UIAlertAction *disableAction = [UIAlertAction actionWithTitle: KKPasscodeLockLocalizedString(@"Passcode_remove_disable", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self showPasswordViewControllerWithMode:KKPasscodeModeDisabled];
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:disableAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
		}
	} else if (indexPath.section == 0 && indexPath.row == 1 && _passcodeLockOn) {
        [self showPasswordViewControllerWithMode:KKPasscodeModeChange];
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
	} else if (indexPath.section == 1) {
        KKPasscodeGracePeriodViewController *gvc = [[KKPasscodeGracePeriodViewController alloc] initWithStyle:UITableViewStyleGrouped];
        [self.navigationController pushViewController:gvc animated:YES];
    }
}

- (void)didSettingsChanged:(KKPasscodeViewController*)viewController
{
    [self readSettings];
    
	[self.tableView reloadData];
	
	if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
		[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
	}
	
}

- (void)readSettings {
    _passcodeLockOn = [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
    _eraseDataOn = [[KKKeychain getStringForKey:@"erase_data_on"] isEqualToString:@"YES"];
    _eraseDataSwitch.on = _eraseDataOn;
    _gracePeriod = [[KKKeychain getStringForKey:@"grace_period"] intValue];
    _touchIdOn = [[KKKeychain getStringForKey:@"touch_id_on"] isEqualToString:@"YES"];
    _touchIdSwitch.on = _touchIdOn;
}

- (void)showPasswordViewControllerWithMode:(KKPasscodeMode)mode {
    JKLLockScreenViewController *vc = [[JKLLockScreenViewController alloc] initWithNibName:NSStringFromClass([JKLLockScreenViewController class]) bundle:[BundleUtil frameworkBundle]];
    switch (mode) {
        case KKPasscodeModeEnter:
            vc.lockScreenMode = LockScreenModeNormal;
            break;
        case KKPasscodeModeSet:
            vc.lockScreenMode = LockScreenModeNew;
            break;
        case KKPasscodeModeDisabled:
            vc.lockScreenMode = LockScreenModeDisable;
            break;
        case KKPasscodeModeChange:
            vc.lockScreenMode = LockScreenModeChangeCheck;
            break;
        default:
            break;
    }
    vc.delegate = self;
    
    UINavigationController *nav = [[ModalNavigationController alloc] initWithRootViewController:vc];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.navigationController presentViewController:nav animated:YES completion:nil];
}

- (void)cancelAction {
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (void)okAction {
    [self showPasswordViewControllerWithMode:KKPasscodeModeSet];
}


+ (NSString*)textForGracePeriod:(int)gracePeriod shortForm:(BOOL)shortForm {
    if (gracePeriod == 0) {
        return KKPasscodeLockLocalizedString(@"Immediately", @"");
    } else if (gracePeriod == 60) {
        if (shortForm)
            return KKPasscodeLockLocalizedString(@"After 1 min.", @"");
        else
            return KKPasscodeLockLocalizedString(@"After 1 minute", @"");
    } else if (gracePeriod < 3600) {
        if (shortForm)
            return [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"After %d min.", @""), gracePeriod / 60];
        else
            return [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"After %d minutes", @""), gracePeriod / 60];
    } else if (gracePeriod == 3600) {
        return KKPasscodeLockLocalizedString(@"After 1 hour", @"");
    } else {
        return [NSString stringWithFormat:KKPasscodeLockLocalizedString(@"After %d hours", @""), gracePeriod / 3600];
    }
}


@end

