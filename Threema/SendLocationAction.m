//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "SendLocationAction.h"
#import "MessageSender.h"
#import "PreviewLocationViewController.h"

@interface SendLocationAction () <PreviewLocationViewControllerDelegate>

@end

@implementation SendLocationAction

- (void)executeAction {
    UINavigationController *previewLocationNav = [self.chatViewController.storyboard instantiateViewControllerWithIdentifier:@"PreviewLocationNav"];
    PreviewLocationViewController *previewLocationVc = previewLocationNav.viewControllers[0];
    previewLocationVc.delegate = self;
    previewLocationNav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.chatViewController.navigationController presentViewController:previewLocationNav animated:YES completion:nil];
}

#pragma mark - Preview location delegate

- (void)previewLocationController:(PreviewLocationViewController *)controller didChooseToSendCoordinate:(CLLocationCoordinate2D)coordinate accuracy:(CLLocationAccuracy)accuracy poiName:(NSString *)poiName poiAddress:(NSString *)poiAddress {
    
    [MessageSender sendLocation:coordinate accuracy:accuracy poiName:poiName poiAddress:poiAddress inConversation:self.chatViewController.conversation onCompletion:^(NSData *messageId) {}];
}

@end
