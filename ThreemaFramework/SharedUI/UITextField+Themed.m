//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "UITextField+Themed.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation UITextField (UITextField)

- (void)colorizeClearButton {
    if (self.clearButtonMode != UITextFieldViewModeNever) {
        self.rightViewMode = self.clearButtonMode;

        UIImage *clearImage = [[UIImage systemImageNamed:@"xmark.circle.fill"] applyingWithSymbolWeight:UIImageSymbolWeightSemibold symbolScale:UIImageSymbolScaleLarge paletteColors:nil];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setImage:clearImage forState:UIControlStateNormal];
        button.tintColor = Colors.backgroundButton;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;

        [button addTarget:self action:@selector(clear:) forControlEvents:UIControlEventTouchUpInside];
        self.rightView = button;

        button.accessibilityLabel = [BundleUtil localizedStringForKey:@"delete"];
    }
}

- (void)clear:(id)sender{
    self.text = @"";
    // textFieldShouldClear will never called for our custom clear button. We use it to update the save button
    if ([self.delegate respondsToSelector:@selector(textFieldShouldClear:)]) {
        [self.delegate textFieldShouldClear:self];
    }
}

@end
