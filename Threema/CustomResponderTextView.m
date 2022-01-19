//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "CustomResponderTextView.h"
#import "StatusNavigationBar.h"
#import "PortraitNavigationController.h"

@implementation CustomResponderTextView

@synthesize overrideNextResponder;
@synthesize pasteImageHandler;

- (UIResponder *)nextResponder {
    if (overrideNextResponder != nil)
        return overrideNextResponder;
    else
        return [super nextResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (overrideNextResponder != nil) {
        return NO;
    } else {
        if (action == @selector(paste:) && pasteImageHandler != nil && !([UIPasteboard generalPasteboard].hasStrings || [UIPasteboard generalPasteboard].hasURLs)) {
            if ([UIPasteboard generalPasteboard].hasImages) {
                return YES;
            }
            
            if (@available(iOS 11.0, *)) {
                return YES;
            }
            return NO;
        } else if (action == @selector(scanQrCode:)) {
            return YES;
            
        } else {
            return [super canPerformAction:action withSender:sender];
        }
    }
}

- (void)paste:(id)sender {
    bool hasTextOrURL = [UIPasteboard generalPasteboard].hasStrings || [UIPasteboard generalPasteboard].hasURLs;
    bool hasImages = [UIPasteboard generalPasteboard].hasImages;
    if (pasteImageHandler != nil && (hasImages || !hasTextOrURL)) {
        if (@available(iOS 11.0, *)) {
            if ([UIPasteboard generalPasteboard].numberOfItems > 0) {
                [pasteImageHandler handlePasteItem];
            }
        } else {
            // Fallback on earlier versions
            if ([UIPasteboard generalPasteboard].image != nil) {
                [pasteImageHandler handlePasteItem];
            }
        }
    } else {
        [super paste:sender];
    }
}

- (void)scanQrCode:(id)sender {
    QRScannerViewController *qrController = [[QRScannerViewController alloc] init];
    
    qrController.delegate = self;
    qrController.title = NSLocalizedString(@"scan_qr", nil);
    
    UINavigationController *nav = [[PortraitNavigationController alloc] initWithNavigationBarClass:[StatusNavigationBar class] toolbarClass:nil];
    [nav pushViewController:qrController animated:NO];
    
    nav.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self.window.rootViewController presentViewController:nav animated:YES completion:nil];
}

#pragma mark - QR scanner delegate

- (void)qrScannerViewController:(QRScannerViewController *)controller didScanResult:(NSString *)result {
    [self insertText:result];
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)qrScannerViewControllerDidCancel:(QRScannerViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
