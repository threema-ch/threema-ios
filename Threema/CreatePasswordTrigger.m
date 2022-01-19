//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "CreatePasswordTrigger.h"
#import "BackupPasswordViewController.h"
#import "BackupPasswordVerifyViewController.h"

@interface CreatePasswordTrigger () <PasswordCallback, UINavigationControllerDelegate>

@property UIViewController *viewController;

@end

CreatePasswordTrigger *createPasswordTriggerInstance;

@implementation CreatePasswordTrigger

+ (instancetype)createPasswordTriggerOn:(UIViewController *)viewController {
    CreatePasswordTrigger *createPasswordTrigger = [[CreatePasswordTrigger alloc] initWithViewController:viewController];
    
    createPasswordTriggerInstance = createPasswordTrigger;
    
    return createPasswordTrigger;
}

- (instancetype)initWithViewController: (UIViewController *) viewController {
    self = [super init];
    if (self) {
        self.viewController = viewController;
    }
    return self;
}

- (void)presentPasswordUI {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CreatePassword" bundle:nil];
    
    UINavigationController *navigationController = (UINavigationController *) [storyboard instantiateInitialViewController];
    navigationController.delegate = self;
    
    if (createPasswordTriggerInstance) {
        [createPasswordTriggerInstance.viewController presentViewController:navigationController animated:YES completion:nil];
    }
}

#pragma mark - UINavigationControllerDelegate

-(void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)vc animated:(BOOL)animated {
    if ([vc isKindOfClass: [BackupPasswordViewController class]]) {
        BackupPasswordViewController *passwordVC = (BackupPasswordViewController *) vc;
        passwordVC.passwordTitle = _passwordTitle;
        passwordVC.passwordAdditionalText = _passwordAdditionalText;
    }
    
    if ([vc isKindOfClass: [BackupPasswordVerifyViewController class]]) {
        BackupPasswordVerifyViewController *passwordVerify = (BackupPasswordVerifyViewController *) vc;
        passwordVerify.passwordCallback = self;
    }
}

#pragma mark - PasswordCallback

- (void)passwordResult:(NSString *)password fromViewController:(UIViewController *)viewController{
    if (_passwordCallback) {
        [_passwordCallback passwordResult: password fromViewController: viewController];
    }
}

@end
