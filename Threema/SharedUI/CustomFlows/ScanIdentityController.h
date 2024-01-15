//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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

#import <Foundation/Foundation.h>
#import "QRScannerViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScanIdentityController : NSObject <QRScannerViewControllerDelegate>

@property (nonatomic, strong) UIViewController *containingViewController;
@property (nonatomic, strong, nullable) NSString *expectedIdentity;

/// Called when the scanning is completed. It will pass `true` if the contact was fully verified.
@property (nonatomic, copy, nullable) void (^completion)(BOOL);

+ (BOOL)canScan;

- (void)startScan;

- (void)playSuccessSound;

@end

NS_ASSUME_NONNULL_END
