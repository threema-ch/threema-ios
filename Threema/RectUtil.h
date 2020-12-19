//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2020 Threema GmbH
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

@interface RectUtil : NSObject

+(CGRect) setPositionOf: (CGRect) rect x:(CGFloat) x y:(CGFloat) y;

+(CGRect) setPositionOf: (CGRect) rect point:(CGPoint) point;

+(CGRect) setYPositionOf: (CGRect) rect y:(CGFloat) y;

+(CGRect) setXPositionOf: (CGRect) rect x:(CGFloat) x;

+(CGRect) changeSizeOf: (CGRect) rect deltaX:(CGFloat) deltaX deltaY:(CGFloat) deltaY;

+(CGRect) setSizeOf: (CGRect) rect width:(CGFloat) width height:(CGFloat) height;

+(CGRect) setWidthOf: (CGRect) rect width:(CGFloat) width;

+(CGRect) setHeightOf: (CGRect) rect height:(CGFloat) height;

+(BOOL) doRectOverlapXExcludingEdgesLeft: (CGRect) left right: (CGRect) right;

+(CGRect)offsetRect: (CGRect) rect byX: (CGFloat) dx byY: (CGFloat) dy;

+(CGRect)offsetAndResizeRect: (CGRect) rect byX: (CGFloat) dx byY: (CGFloat) dy;

+ (CGRect) rectZeroAtCenterOf: (CGRect) rect;

+ (CGRect) moveRect: (CGRect) rect to: (CGPoint) point keepingOffset: (CGPoint) diff;

+ (CGRect) growRect: (CGRect) rect byDx: (CGFloat) dX byDy: (CGFloat) dY;

+ (CGRect) growRectBaseline: (CGRect) rect byDx: (CGFloat) dX byDy: (CGFloat) dY;

+ (CGRect) rect: (CGRect) rect centerIn: (CGRect) outerRect;

+ (CGRect) rect: (CGRect) rect centerIn: (CGRect) outerRect round: (BOOL) round;

+ (CGRect) rect: (CGRect) rect centerVerticalIn: (CGRect) outerRect;
+ (CGRect) rect: (CGRect) rect centerVerticalIn: (CGRect) outerRect round: (BOOL) round;

+ (CGRect) rect: (CGRect) rect centerHorizontalIn: (CGRect) outerRect;
+ (CGRect) rect: (CGRect) rect centerHorizontalIn: (CGRect) outerRect round: (BOOL) round;

+ (CGPoint) centerOf: (CGRect) rect;

+ (CGFloat) distancePoint: (CGPoint) p1 toPoint: (CGPoint) p2;

+ (CGRect) rect: (CGRect) rect alignVerticalWith: (CGRect) outerRect round: (BOOL) round;

+ (CGRect) rect: (CGRect) rect centerAlignWith: (CGRect) outerRect round: (BOOL) round;

@end
