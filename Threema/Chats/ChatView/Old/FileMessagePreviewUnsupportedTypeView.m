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

#import "FileMessagePreviewUnsupportedTypeView.h"
#import "BundleUtil.h"
#import "ThreemaUtilityObjC.h"
#import "FileMessagePreview.h"

@implementation FileMessagePreviewUnsupportedTypeView

+ (instancetype)fileMessagePreviewUnsupportedTypeView {
    FileMessagePreviewUnsupportedTypeView *view = (FileMessagePreviewUnsupportedTypeView *)[BundleUtil loadXibNamed:@"FileMessagePreviewUnsupportedTypeView"];

    view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    view.noPreviewLabel.textColor = UIColor.labelColor;
    view.fileNameLabel.textColor = UIColor.labelColor;
    view.fileSizeLabel.textColor = UIColor.secondaryLabelColor;
    
    return view;
}

- (void)setFileMessageEntity:(FileMessageEntity *)fileMessageEntity {
    [_noPreviewLabel setText:[BundleUtil localizedStringForKey:@"no_preview_available"]];

    [_fileNameLabel setText:fileMessageEntity.fileName];
    [_fileSizeLabel setText: [ThreemaUtilityObjC formatDataLength:fileMessageEntity.fileSize.floatValue]];
    
    _thumbnailImage.image = [FileMessagePreview thumbnailForFileMessageEntity:fileMessageEntity];
}

@end
