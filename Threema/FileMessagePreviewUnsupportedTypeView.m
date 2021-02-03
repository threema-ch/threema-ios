//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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
#import "Utils.h"
#import "FileMessagePreview.h"

@implementation FileMessagePreviewUnsupportedTypeView

+ (instancetype)fileMessagePreviewUnsupportedTypeView {
    FileMessagePreviewUnsupportedTypeView *view = (FileMessagePreviewUnsupportedTypeView *)[BundleUtil loadXibNamed:@"FileMessagePreviewUnsupportedTypeView"];

    return view;
}

- (void)setupColors {
    _noPreviewLabel.textColor = [Colors fontNormal];
    _fileNameLabel.textColor = [Colors fontNormal];
    _fileSizeLabel.textColor = [Colors fontNormal];
    
    self.backgroundColor = [Colors background];
}

- (void)setFileMessage:(FileMessage *)message {
    [_noPreviewLabel setText:[BundleUtil localizedStringForKey:@"no_preview_available"]];

    [_fileNameLabel setText:message.fileName];
    [_fileSizeLabel setText: [Utils formatDataLength:message.fileSize.floatValue]];
    
    _thumbnailImage.image = [FileMessagePreview thumbnailForFileMessage:message];
    
    [self setupColors];
}

@end
