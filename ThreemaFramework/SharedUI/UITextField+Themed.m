#import "UITextField+Themed.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

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
