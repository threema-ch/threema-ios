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

#import <MobileCoreServices/UTCoreTypes.h>

#import "EditableAvatarView.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "UIDefines.h"
#import "UIImage+Resize.h"
#import "RectUtil.h"
#import "BundleUtil.h"
#import "AvatarMaker.h"
#import <RSKImageCropper/RSKImageCropViewController.h>

@interface EditableAvatarView () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, RSKImageCropViewControllerDelegate>

@property UIImagePickerController *imagePicker;
@property NSInteger takePhotoIndex;
@property NSInteger chooseExistingIndex;
@property NSData *currentImageData;

@end

@implementation EditableAvatarView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupViews];
        _isReceivedImage = NO;
    }
    return self;
}


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
        _isReceivedImage = NO;
    }
    return self;
}

- (void)setImageData:(NSData *)imageData {
    _currentImageData = imageData;
    [self updateView];
}

- (NSData *)imageData {
    return _currentImageData;
}

- (void)setCanDeleteImage:(BOOL)canDeleteImage {
    _canDeleteImage = canDeleteImage;
    [self updatePlaceholderView];
}

- (void)setCanChooseImage:(BOOL)canChooseImage {
    _canChooseImage = canChooseImage;
    [self updatePlaceholderView];
}

- (void)setupViews {
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [self addSubview:_imageView];
    _pickImageLabel.userInteractionEnabled = YES;
    
    CGRect rect = CGRectInset(_imageView.frame, 10.0, 10.0);
    _pickImageLabel = [[UILabel alloc] initWithFrame:rect];
    _pickImageLabel.numberOfLines = 3;
    _pickImageLabel.font = [UIFont systemFontOfSize:15.0];
    _pickImageLabel.minimumScaleFactor = 0.6;
    _pickImageLabel.adjustsFontSizeToFitWidth = YES;
    _pickImageLabel.text = [BundleUtil localizedStringForKey:@"pick image"];
    _pickImageLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_pickImageLabel];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedImage)];
    [_imageView addGestureRecognizer:tapRecognizer];
    _imageView.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tapLabelRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedImage)];
    [_pickImageLabel addGestureRecognizer:tapLabelRecognizer];
    _pickImageLabel.userInteractionEnabled = YES;
    
    _imageView.accessibilityIgnoresInvertColors = true;
    
    self.backgroundColor = [UIColor clearColor];
    
    [self updateView];
}

- (void)updateView {
    if (_currentImageData) {
        UIImage *image = [UIImage imageWithData:_currentImageData];
        _imageView.image = [AvatarMaker maskImage: image];
        _pickImageLabel.hidden = YES;
    } else {
        _imageView.image = [AvatarMaker avatarWithString:nil size:(_imageView.frame.size.height * [UIScreen mainScreen].scale)];
        _pickImageLabel.hidden = NO;
    }
}

- (void)updatePlaceholderView {
    _imageView.userInteractionEnabled = _canDeleteImage || _canChooseImage;
    _pickImageLabel.userInteractionEnabled = _canDeleteImage || _canChooseImage;
    _pickImageLabel.textColor = _canDeleteImage || _canChooseImage ? Colors.text : Colors.textPlaceholder;
}

- (void)tappedImage {
    if (!_canDeleteImage && !_canChooseImage) {
        return;
    }
    
    [_presentingViewController resignFirstResponder];
    
    if (!_isReceivedImage) {
        /* allow the user to choose a new image or clear the current one */
        UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] && _canChooseImage) {
            [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"take_photo"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
                _imagePicker = [[UIImagePickerController alloc] init];
                _imagePicker.delegate = self;
                _imagePicker.allowsEditing = NO;
                _imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                _imagePicker.mediaTypes = @[(NSString*)UTTypeImage.identifier];
                
                CGRect rect = [_presentingViewController.view convertRect:self.frame fromView:self.superview];
                [ModalPresenter present:_imagePicker on:_presentingViewController fromRect:rect inView:_presentingViewController.view];
            }]];
        }
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] && _canChooseImage) {
            [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"choose_existing"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
                _imagePicker = [[UIImagePickerController alloc] init];
                _imagePicker.delegate = self;
                _imagePicker.allowsEditing = NO;
                _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                _imagePicker.mediaTypes = @[(NSString*)UTTypeImage.identifier];
                
                CGRect rect = [_presentingViewController.view convertRect:self.frame fromView:self.superview];
                [ModalPresenter present:_imagePicker on:_presentingViewController fromRect:rect inView:_presentingViewController.view];
            }]];
        }
        if (_currentImageData != nil && _canDeleteImage) {
            [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete_photo"] style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * action) {
                _currentImageData = nil;
                [self updateView];
                [_delegate avatarImageUpdated:_currentImageData];
            }]];
        }
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction * action) {
            
        }]];
        
        if (SYSTEM_IS_IPAD == YES || !_presentingViewController.tabBarController) {
            CGRect rect = [_presentingViewController.view convertRect:self.frame fromView:self.superview];
            actionSheet.popoverPresentationController.sourceRect = rect;
            actionSheet.popoverPresentationController.sourceView = self;
        }
        
        [[[AppDelegate sharedAppDelegate] currentTopViewController] presentViewController:actionSheet animated:YES completion:nil];
    }
}


#pragma mark - Image picker controller delegate

- (void)imagePickerController:(UIImagePickerController *)_picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    RSKImageCropViewController *imageCropViewController = [[RSKImageCropViewController alloc] initWithImage:image];
    imageCropViewController.delegate = self;
    imageCropViewController.cropMode = RSKImageCropModeCircle;
    imageCropViewController.avoidEmptySpaceAroundImage = YES;
    CGSize maskSize = CGSizeMake(kContactImageSize, kContactImageSize);
    imageCropViewController.preferredContentSize = CGSizeMake(maskSize.width, maskSize.height);
    [ModalPresenter dismissPresentedControllerOn:_presentingViewController animated:YES];
    CGRect rect = [_presentingViewController.view convertRect:self.frame fromView:self.superview];
    [ModalPresenter present:imageCropViewController on:_presentingViewController fromRect:rect inView:_presentingViewController.view];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)_picker {
    [ModalPresenter dismissPresentedControllerOn:_presentingViewController animated:YES];
    _imagePicker = nil;
    
    [_delegate avatarImageUpdated:_currentImageData];
}

#pragma mark - RSKImageCropViewControllerDelegate

// Crop image has been canceled.
- (void)imageCropViewControllerDidCancelCrop:(RSKImageCropViewController *)controller
{
    [ModalPresenter dismissPresentedControllerOn:_presentingViewController animated:YES];
    _imagePicker = nil;
    
    [_delegate avatarImageUpdated:_currentImageData];
}

// The original image has been cropped. Additionally provides a rotation angle used to produce image.
- (void)imageCropViewController:(RSKImageCropViewController *)controller didCropImage:(UIImage *)croppedImage usingCropRect:(CGRect)cropRect rotationAngle:(CGFloat)rotationAngle
{
    UIImage *resizedImage = [croppedImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(kContactImageSize, kContactImageSize) interpolationQuality:kCGInterpolationHigh];
    
    _currentImageData = UIImageJPEGRepresentation(resizedImage, 0.7f);
    [self updateView];
    [_delegate avatarImageUpdated:_currentImageData];
    
    [ModalPresenter dismissPresentedControllerOn:_presentingViewController animated:YES];
}


#pragma mark - Accessibility

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityLabel {
    if (_currentImageData) {
        NSString *image = [BundleUtil localizedStringForKey:@"image"];
        NSString *action = [BundleUtil localizedStringForKey:@"tap_to_change"];
        
        return [NSString stringWithFormat:@"%@, %@", image, action];
    } else {
        return _pickImageLabel.text;
    }
}

@end
