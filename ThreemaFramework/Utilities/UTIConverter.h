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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define UTTYPE_IMAGE ((NSString *)kUTTypeImage)
#define UTTYPE_GIF_IMAGE ((NSString *)kUTTypeGIF)
#define UTTYPE_VIDEO ((NSString *)kUTTypeVideo)
#define UTTYPE_MOVIE ((NSString *)kUTTypeMovie)
#define UTTYPE_AUDIO ((NSString *)kUTTypeAudio)
#define UTTYPE_PLAIN_TEXT ((NSString *)kUTTypePlainText)
#define UTTYPE_URL ((NSString *)kUTTypeURL)
#define UTTYPE_FILE_URL ((NSString *)kUTTypeFileURL)
#define UTTYPE_VCARD ((NSString *)kUTTypeVCard)

#define UTTYPE_ITEM ((NSString *)kUTTypeItem)
#define UTTYPE_DATA ((NSString *)kUTTypeData)
#define UTTYPE_CONTENT ((NSString *)kUTTypeContent)
#define UTTYPE_ARCHIVE ((NSString *)kUTTypeArchive)
#define UTTYPE_CONTACT ((NSString *)kUTTypeContact)
#define UTTYPE_MESSAGE ((NSString *)kUTTypeMessage)

@interface UTIConverter : NSObject

+ (NSString *)mimeTypeFromUTI:(NSString *)uti;

+ (NSString *)utiFromMimeType:(NSString *)mimeType;

+ (NSString *)utiForFileURL:(NSURL *)url;

+ (nullable NSString *)preferredFileExtensionForMimeType:(NSString *)mimeType;

+ (BOOL)isImageMimeType:(NSString *)mimeType;

+ (BOOL)isRenderingImageMimeType:(NSString *)mimeType;

+ (BOOL)isPNGImageMimeType:(NSString *)mimeType;

+ (BOOL)isGifMimeType:(NSString *)mimeType;

+ (BOOL)isAudioMimeType:(NSString *)mimeType;

+ (BOOL)isRenderingAudioMimeType:(NSString *)mimeType;

+ (NSArray<NSString *>*_Nonnull)renderingAudioMimetypes;

+ (BOOL)isVideoMimeType:(NSString *)mimeType;

+ (BOOL)isMovieMimeType:(NSString *)mimeType;

+ (BOOL)isRenderingVideoMimeType:(NSString *)mimeType;

+ (BOOL)isPDFMimeType:(NSString *)mimeType;

+ (BOOL)isContactMimeType:(NSString *)mimeType;

+ (BOOL)isCalendarMimeType:(NSString *)mimeType;

+ (BOOL)isArchiveMimeType:(NSString *)mimeType;

+ (BOOL)isWordMimeType:(NSString *)mimeType;

+ (BOOL)isPowerpointMimeType:(NSString *)mimeType;

+ (BOOL)isExcelMimeType:(NSString *)mimeType;

+ (BOOL)isTextMimeType:(NSString *)mimeType;

+ (BOOL)isPassMimeType:(NSString *)mimeType;

+ (BOOL)type:(NSString *)type conformsTo:(NSString *)referenceType;

+ (BOOL)conformsToMovieType:(NSString *)mimeType;

+ (BOOL)conformsToImageType:(NSString *)mimeType;

+ (UIImage *)getDefaultThumbnailForMimeType:(NSString *)mimeType;

@end
