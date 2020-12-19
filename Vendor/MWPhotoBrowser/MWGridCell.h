// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  MWGridCell.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import <UIKit/UIKit.h>
#import "MWPhoto.h"
#import "MWGridViewController.h"

@interface MWGridCell : UICollectionViewCell {}

@property (nonatomic, weak) MWGridViewController *gridController;
@property (nonatomic) NSUInteger index;
@property (nonatomic) id <MWPhoto> photo;
@property (nonatomic) BOOL selectionMode;
@property (nonatomic) BOOL isSelected;

- (void)displayImage;
///***** BEGIN THREEMA MODIFICATION: added as public function *********/
- (void)selectionButtonPressed;
///***** BEGIN THREEMA MODIFICATION: added as public function *********/

@end
