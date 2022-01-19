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

#import "BundleUtil.h"

@implementation BundleUtil

+ (NSBundle *)frameworkBundle {
    NSBundle *frameworkBundle = [NSBundle bundleWithIdentifier:THREEMA_FRAMEWORK_IDENTIFIER];
    return frameworkBundle;
}

+ (NSBundle *)mainBundle {
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url;
    while (![[bundle.bundleURL pathExtension] isEqualToString:@"app"]) {
        url = [bundle.bundleURL URLByDeletingLastPathComponent];
        if (!url) {
            return nil;
        }
        bundle = [NSBundle bundleWithURL:url];
    }
    return bundle;
}

+ (NSString *)threemaAppGroupIdentifier {
    NSAssert([[BundleUtil mainBundle] objectForInfoDictionaryKey:@"ThreemaAppGroupIdentifier"] != nil, @"Bundle ThreemaAppGroupIdentifier not set");
    return [[BundleUtil mainBundle] objectForInfoDictionaryKey:@"ThreemaAppGroupIdentifier"];
}

+ (NSString *)threemaAppIdentifier {
    NSAssert([[BundleUtil mainBundle] objectForInfoDictionaryKey:@"ThreemaAppIdentifier"] != nil, @"Bundle ThreemaAppIdentifier not set");
    return [[BundleUtil mainBundle] objectForInfoDictionaryKey:@"ThreemaAppIdentifier"];
}


+ (id)objectForInfoDictionaryKey:(NSString *)key {
    id value = [[self frameworkBundle] objectForInfoDictionaryKey:key];
    if (value == nil) {
        // fall back to main bundle
        value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    }

    return value;
}

+ (NSString *)pathForResource:(NSString *)resource ofType:(NSString *)type {
    NSString *path = [[self frameworkBundle] pathForResource:resource ofType:type];

    if (path == nil) {
        // fall back to main bundle
        path = [[NSBundle mainBundle] pathForResource:resource ofType:type];
    }
    
    return path;
}

+ (NSURL *)URLForResource:(NSString *)resourceName withExtension:(NSString *)extension {
    NSURL *url =  [[self frameworkBundle] URLForResource:resourceName withExtension:extension];
    if (url == nil) {
        // fall back to main bundle
        url = [[NSBundle mainBundle] URLForResource:resourceName withExtension:extension];
    }
    
    return url;
}

+ (UIImage *)imageNamed:(NSString *)imageName {
    NSBundle *frameworkBundle = [self frameworkBundle];
    UIImage *image;
    
    if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)])
    {
        image = [UIImage imageNamed:imageName inBundle:frameworkBundle compatibleWithTraitCollection:nil];
    } else {
        image = [UIImage imageNamed:[NSString stringWithFormat:@"ThreemaFramework.bundle/%@", imageName]];
    }

    if (image) {
        return image;
    }
    
    image = [UIImage imageNamed:imageName inBundle:[self mainBundle] compatibleWithTraitCollection:nil];
    
    if (image) {
        return image;
    }

    image = [UIImage imageNamed:imageName];

    if (image) {
        return image;
    }

    NSString *path = [frameworkBundle pathForResource:imageName ofType:nil];
    if ([path length] > 0) {
        image = [UIImage imageWithContentsOfFile:path];
    }

    return image;
}

+ (NSString *)localizedStringForKey:(NSString *)key {
    NSString *value = [[self frameworkBundle] localizedStringForKey:key value:nil table:nil];
    
    if (value && [value isEqualToString:key] == NO) {
        return value;
    } else if ((value = [[self mainBundle] localizedStringForKey:key value:nil table:nil]) && ([value isEqual:key] == NO)) {
        return value;
    } else {
        return NSLocalizedString(key, nil);
    }
}

+ (UIView *)loadXibNamed:(NSString *)name {
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *nibs =  [bundle loadNibNamed:name owner:self options:nil];
    if (nibs == nil) {
        // fall back to main bundle
        nibs = [[NSBundle mainBundle] loadNibNamed:name owner:self options:nil];
    }

    UIView *view = [nibs objectAtIndex:0];
    
    return view;
}

@end
