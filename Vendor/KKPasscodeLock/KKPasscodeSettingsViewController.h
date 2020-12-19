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

#import <UIKit/UIKit.h>
#import "KKPasscodeViewController.h"
#import "ThemedTableViewController.h"
#import "JKLLockScreenViewController.h"

@class KKPasscodeSettingsViewController;

@protocol KKPasscodeSettingsViewControllerDelegate <NSObject>

@optional

/**
 * called when the passcode settings (either turned on/off) is changed
 */
- (void)didSettingsChanged:(KKPasscodeSettingsViewController*)viewController;

@end

@interface KKPasscodeSettingsViewController : ThemedTableViewController <UIAlertViewDelegate, KKPasscodeViewControllerDelegate, JKLLockScreenViewControllerDelegate> {
	
    // delegate which notified then the passcode is turned on/off
	id <KKPasscodeSettingsViewControllerDelegate> __unsafe_unretained _delegate;
	
    // the erase content switch.
	UISwitch* _eraseDataSwitch;
    
    UISwitch* _touchIdSwitch;
	
    // whatever the passcode lock is turned on or off
	BOOL _passcodeLockOn;
    
    // whatever the erase data option is turned on or off
	BOOL _eraseDataOn;
    
    // seconds before passcode is required
    int _gracePeriod;
    
    // whether Touch ID is enabled
    BOOL _touchIdOn;
}

@property (nonatomic, unsafe_unretained) id <KKPasscodeSettingsViewControllerDelegate> delegate;

+ (NSString*)textForGracePeriod:(int)gracePeriod shortForm:(BOOL)shortForm;

@end
