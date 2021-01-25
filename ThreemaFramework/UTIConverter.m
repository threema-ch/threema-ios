//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "UTIConverter.h"
#import "BundleUtil.h"

@implementation UTIConverter

+ (NSString *)mimeTypeFromUTI:(NSString *)uti {
    if ([uti isEqualToString:UTTYPE_VCARD]) {
        return @"text/vcard";
    }
        
    CFStringRef UTI = (__bridge CFStringRef)uti;
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    NSString *MIMETypeString = (__bridge_transfer NSString *)MIMEType;
    
    if (MIMETypeString) {
        return MIMETypeString;
    } else {
        // fallback if unknown
        return @"application/octet-stream";
    }
}

+ (NSString *)utiFromMimeType:(NSString *)mimeType {
    CFStringRef MIMEType = (__bridge CFStringRef)mimeType;
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, MIMEType, NULL);
    NSString *UTIString = (__bridge_transfer NSString *)UTI;
    
    return UTIString;
}

+ (NSString *)utiForFileURL:(NSURL *)url {
    CFStringRef fileExtension = (__bridge CFStringRef)[url pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
    NSString *UTIString = (__bridge_transfer NSString *)UTI;
    
    return UTIString;
}

+ (NSString *)preferedFileExtensionForMimeType:(NSString *)mimeType {
    CFStringRef mimeTypeRef = (__bridge CFStringRef)mimeType;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeTypeRef, NULL);
    CFStringRef fileExtensionRef = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    NSString *fileExtension = (__bridge_transfer NSString *)fileExtensionRef;
    
    return fileExtension;
}

+ (BOOL)isImageMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeImage mimeType:mimeType];
}

+ (BOOL)isRenderingImageMimeType:(NSString *)mimeType {
    if ([self isKind:kUTTypeJPEG mimeType:mimeType] || [self isKind:kUTTypePNG mimeType:mimeType]) {
        return true;
    }
    return false;
}

+ (BOOL)isPNGImageMimeType:(NSString *)mimeType {
    if ([self isKind:kUTTypePNG mimeType:mimeType]) {
        return true;
    }
    return false;
}

+ (BOOL)isRenderingVideoMimeType:(NSString *)mimeType {
    if ([mimeType isEqualToString:@"video/mp4"] || [mimeType isEqualToString:@"video/mpeg4"] || [mimeType isEqualToString:@"video/x-m4v"]) {
        return true;
    }
    return false;
}

+ (BOOL)isRenderingAudioMimeType:(NSString *)mimeType {
    if ([mimeType isEqualToString:@"audio/aac"] || [mimeType isEqualToString:@"audio/m4a"] || [mimeType isEqualToString:@"audio/x-m4a"] || [mimeType isEqualToString:@"audio/mp4"]) {
        return true;
    }

    return false;
}

+ (BOOL)isGifMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeGIF mimeType:mimeType];
}

+ (BOOL)isAudioMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeAudio mimeType:mimeType];
}

+ (BOOL)isVideoMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeVideo mimeType:mimeType];
}

+ (BOOL)isMovieMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeMovie mimeType:mimeType];
}

+ (BOOL)isPDFMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypePDF mimeType:mimeType];
}

+ (BOOL)isContactMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeContact mimeType:mimeType];
}

+ (BOOL)isCalendarMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeCalendarEvent mimeType:mimeType];
}

+ (BOOL)isArchiveMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeArchive mimeType:mimeType];
}

+ (BOOL)isPublicContentMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeContent mimeType:mimeType];
}

+ (BOOL)isPublicCompositeContentMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeCompositeContent mimeType:mimeType];
}

+ (BOOL)isWordMimeType:(NSString *)mimeType {
    if ([mimeType hasPrefix:@"application/vnd.openxmlformats-officedocument.wordprocessingml"]) {
        return YES;
    }

    return [mimeType isEqualToString:@"application/msword"];
}

+ (BOOL)isPowerpointMimeType:(NSString *)mimeType {
    if ([mimeType hasPrefix:@"application/vnd.openxmlformats-officedocument.presentationml"]) {
        return YES;
    }
    
    return [mimeType isEqualToString:@"application/vnd.ms-powerpointtd"];
}

+ (BOOL)isExcelMimeType:(NSString *)mimeType {
    if ([mimeType hasPrefix:@"application/vnd.openxmlformats-officedocument.spreadsheetml"]) {
        return YES;
    }
    
    return [mimeType isEqualToString:@"application/vnd.ms-excel"];
}

+ (BOOL)isTextMimeType:(NSString *)mimeType {
    return [self isKind:kUTTypeText mimeType:mimeType];
}

+ (BOOL)isPassMimeType:(NSString *)mimeType {
    return [mimeType hasPrefix:@"application/vnd.apple.pkpass"];
}

+ (BOOL)type:(NSString *)type conformsTo:(NSString *)referenceType {
    return UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)referenceType);
}

+ (BOOL)conformsToImageType:(NSString *)uti {
    return [UTIConverter type:uti conformsTo:UTTYPE_IMAGE];
}

+ (BOOL)conformsToMovieType:(NSString *)uti {
    return [UTIConverter type:uti conformsTo:UTTYPE_MOVIE];
}

+ (BOOL)isKind:(CFStringRef)type mimeType:(NSString *)mimeType {
    CFStringRef MIMEType = (__bridge CFStringRef)mimeType;
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, MIMEType, NULL);
    BOOL isKindOfType = UTTypeConformsTo(UTI, type);
    CFRelease(UTI);
    return isKindOfType;
}

+ (UIImage *)getDefaultThumbnailForMimeType:(NSString *)mimeType {
    if ([UTIConverter isImageMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbImageFile"];
    }
    
    if ([UTIConverter isAudioMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbAudioFile"];
    }
    
    if ([UTIConverter isVideoMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbVideoFile"];
    }
    
    if ([UTIConverter isPDFMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbPDF"];
    }
    
    if ([UTIConverter isContactMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbBusinessContact"];
    }
    
    if ([UTIConverter isCalendarMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbCalendar"];
    }
    
    if ([UTIConverter isWordMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbWord"];
    }
    
    if ([UTIConverter isPowerpointMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbPowerpoint"];
    }
    
    if ([UTIConverter isExcelMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbExcel"];
    }
    
    if ([UTIConverter isTextMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbDocument"];
    }
    
    if ([UTIConverter isArchiveMimeType:mimeType]) {
        return [BundleUtil imageNamed:@"ThumbArchive"];
    }
    
    // fallback
    return [BundleUtil imageNamed:@"ThumbFile"];
}

+ (NSString *)localizedDescriptionForMimeType:(NSString *)mimeType {
    CFStringRef MIMEType = (__bridge CFStringRef)mimeType;
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, MIMEType, NULL);

    CFStringRef description = UTTypeCopyDescription(UTI);
    
    return (__bridge_transfer NSString *)description;
}

@end
