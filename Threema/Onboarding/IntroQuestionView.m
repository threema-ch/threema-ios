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

#import "IntroQuestionView.h"
#import "BundleUtil.h"

@implementation IntroQuestionView

- (void)awakeFromNib {
    [self setup];

    [super awakeFromNib];
}

- (void)setShowOnlyOkButton:(BOOL)showOnlyOkButton {
    _alertPane.hidden = (showOnlyOkButton == NO);
    _okButton.hidden = (showOnlyOkButton == NO);
    _confirmPane.hidden = showOnlyOkButton;
    _yesButton.hidden = showOnlyOkButton;
    _noButton.hidden = showOnlyOkButton;
}

- (BOOL)showOnlyOkButton {
    return _yesButton.hidden;
}

- (void)setTitle:(NSString *)title {
    _questionTitle.hidden = ([title  isEqual: @""]);
    _questionTitle.text = title;
}

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    
    _yesButton.layer.cornerRadius = 3;
    _okButton.layer.cornerRadius = 3;
    
    _yesButton.backgroundColor = UIColor.tintColor;
    [_yesButton setTitleColor:Colors.textProminentButtonWizard forState:UIControlStateNormal];
    _yesButton.accessibilityIdentifier = @"setupYesButton";
    _okButton.backgroundColor = UIColor.tintColor;
    [_okButton setTitleColor:Colors.textProminentButtonWizard forState:UIControlStateNormal];
    _okButton.accessibilityIdentifier = @"setupOKButton";

    _noButton.layer.borderWidth = 1;
    _noButton.layer.borderColor = _yesButton.backgroundColor.CGColor;
    _noButton.layer.cornerRadius = 3;
    // With a transparent background, the button is only accessible when the finger is positioned over the text
    _noButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.02];
    _noButton.accessibilityIdentifier = @"IntroQuestionViewNoButton";

    [_yesButton setTitle:[BundleUtil localizedStringForKey:@"yes"] forState:UIControlStateNormal];
    [_noButton setTitle:[BundleUtil localizedStringForKey:@"no"] forState:UIControlStateNormal];
    [_okButton setTitle:[BundleUtil localizedStringForKey:@"ok"] forState:UIControlStateNormal];
    
    [_noButton setTitleColor:UIColor.tintColor forState:UIControlStateNormal];
}

- (IBAction)yesAction:(id)sender {
    [_delegate selectedYes:self];
}

- (IBAction)noAction:(id)sender {
    [_delegate selectedNo:self];
}

- (IBAction)okAction:(id)sender {
    [_delegate selectedOk:self];
}

@end
