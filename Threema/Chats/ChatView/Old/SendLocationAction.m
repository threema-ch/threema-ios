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

#import "SendLocationAction.h"
#import "Threema-Swift.h"

@interface SendLocationAction ()

@end

@implementation SendLocationAction

- (void)executeAction {
    [[ServerInfoProviderFactory makeServerInfoProvider] mapsServerWithCompletionHandler:^(MapsServerInfo * _Nullable mapsServerInfo, __unused NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SendLocationViewController *previewLocationVc = [[SendLocationViewController alloc] initWithConversation:self.chatViewController.conversation mapsServerInfo:mapsServerInfo];
            ModalNavigationController *previewLocationNav = [[ModalNavigationController alloc] initWithRootViewController:previewLocationVc];
            previewLocationNav.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.chatViewController.navigationController presentViewController:previewLocationNav animated:YES completion:nil];
        });
    }];
}

@end
