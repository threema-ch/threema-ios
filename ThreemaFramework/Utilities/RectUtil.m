//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "RectUtil.h"

@implementation RectUtil

+(CGRect) setPositionOf: (CGRect) rect x:(CGFloat) x y:(CGFloat) y
{
    return CGRectMake(x, y, rect.size.width, rect.size.height);
}

+(CGRect) setPositionOf: (CGRect) rect point:(CGPoint) point
{
    return CGRectMake(point.x, point.y, rect.size.width, rect.size.height);
}

+(CGRect) setXPositionOf: (CGRect) rect x:(CGFloat) x
{
    return CGRectMake(x, rect.origin.y, rect.size.width, rect.size.height);
}

+(CGRect) setYPositionOf: (CGRect) rect y:(CGFloat) y
{
    return CGRectMake(rect.origin.x, y, rect.size.width, rect.size.height);
}

+(CGRect) changeSizeOf: (CGRect) rect deltaX:(CGFloat) deltaX deltaY:(CGFloat) deltaY
{
     return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width + deltaX, rect.size.height + deltaY);
}

+(CGRect) setSizeOf: (CGRect) rect width:(CGFloat) width height:(CGFloat) height
{
    return CGRectMake(rect.origin.x, rect.origin.y, width, height);
}

+(CGRect) setWidthOf: (CGRect) rect width:(CGFloat) width
{
    return CGRectMake(rect.origin.x, rect.origin.y, width, rect.size.height);
}

+(CGRect) setHeightOf: (CGRect) rect height:(CGFloat) height
{
    return CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, height);
}

+(BOOL) doRectOverlapXExcludingEdgesLeft: (CGRect) left right: (CGRect) right
{
    CGFloat leftMinX = CGRectGetMinX(left);
    CGFloat leftMaxX = CGRectGetMaxX(left);
    
    CGFloat rightMinX = CGRectGetMinX(right);
    CGFloat rightMaxX = CGRectGetMaxX(right);
    
    if (leftMinX > rightMinX && leftMinX < rightMaxX) {
        return TRUE;
    }

    if (leftMaxX > rightMinX && leftMaxX < rightMaxX) {
        return TRUE;
    }

    if (rightMinX > leftMinX && rightMinX < leftMaxX) {
        return TRUE;
    }
    
    if (rightMaxX > leftMinX && rightMaxX < leftMaxX) {
        return TRUE;
    }

    if (leftMinX == rightMinX && leftMaxX == rightMaxX) {
        return TRUE;
    }

    return FALSE;
}

+ (CGRect)offsetRect: (CGRect) rect byX: (CGFloat) dx byY: (CGFloat) dy
{
    CGRect newRect = CGRectMake(rect.origin.x + dx, rect.origin.y + dy, rect.size.width, rect.size.height);
    
    return newRect;
}

+ (CGRect)offsetAndResizeRect: (CGRect) rect byX: (CGFloat) dx byY: (CGFloat) dy
{
    CGRect newRect = CGRectMake(rect.origin.x + dx, rect.origin.y + dy, rect.size.width - dx, rect.size.height - dy);
    
    return newRect;
}

+ (CGRect) rectZeroAtCenterOf: (CGRect) rect
{
    CGFloat x = rect.origin.x + rect.size.width/2.0;
    CGFloat y = rect.origin.y + rect.size.height/2.0;
    
    return CGRectMake(x, y, 0.0, 0.0);
}

+ (CGRect) moveRect: (CGRect) rect to: (CGPoint) point keepingOffset: (CGPoint) offset
{
    CGFloat x = point.x + offset.x;
    CGFloat y = point.y + offset.y;
    
    return [RectUtil setPositionOf:rect x: x y: y ];
}

+ (CGRect) growRect: (CGRect) rect byDx: (CGFloat) dX byDy: (CGFloat) dY
{
    CGFloat x = rect.origin.x - dX / 2.0;
    CGFloat y = rect.origin.y - dY / 2.0;
    CGFloat width = rect.size.width + dX;
    CGFloat height = rect.size.height + dY;
    
    return CGRectMake(x, y, width, height);
}

+ (CGRect) growRectBaseline: (CGRect) rect byDx: (CGFloat) dX byDy: (CGFloat) dY
{
    CGFloat x = rect.origin.x - dX / 2.0;
    CGFloat y = rect.origin.y - dY;
    CGFloat width = rect.size.width + dX;
    CGFloat height = rect.size.height + dY;
    
    return CGRectMake(x, y, width, height);
}

+ (CGRect) rect: (CGRect) rect centerIn: (CGRect) outerRect {
    return [RectUtil rect: rect centerIn: outerRect round: NO];
}

+ (CGRect) rect: (CGRect) rect centerIn: (CGRect) outerRect round: (BOOL) round
{
    CGFloat innerWidth = rect.size.width;
    CGFloat outerWidth = outerRect.size.width;
    
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = (outerWidth - innerWidth) / 2.0;
    CGFloat y = (outerHeight - innerHeight) / 2.0;
    
    if (round) {
        x = roundf(x);
        y = roundf(y);
    }
    
    return [RectUtil setPositionOf: rect x: x y: y];
}

+ (CGRect) rect: (CGRect) rect centerVerticalIn: (CGRect) outerRect
{
    return [RectUtil rect: rect centerVerticalIn: outerRect round:NO];
}

+ (CGRect) rect: (CGRect) rect centerVerticalIn: (CGRect) outerRect round: (BOOL) round
{
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = rect.origin.x;
    CGFloat y = (outerHeight - innerHeight) / 2.0;
    if (round)
        y = roundf(y);
    
    return [RectUtil setPositionOf: rect x: x y: y];
}

+ (CGRect) rect: (CGRect) rect centerHorizontalIn: (CGRect) outerRect
{
    return [RectUtil rect: rect centerHorizontalIn: outerRect round:NO];
}

+ (CGRect) rect: (CGRect) rect centerHorizontalIn: (CGRect) outerRect round: (BOOL) round
{
    CGFloat innerWidth = rect.size.width;
    CGFloat outerWidth = outerRect.size.width;
    
    CGFloat x = (outerWidth - innerWidth) / 2.0;
    if (round)
        x = roundf(x);
    CGFloat y = rect.origin.y;
    
    return [RectUtil setPositionOf: rect x: x y: y];
}

+ (CGPoint) centerOf: (CGRect) rect
{
    CGFloat x = rect.origin.x + rect.size.width/2.0;
    CGFloat y = rect.origin.y + rect.size.height/2.0;
    
    return CGPointMake(x, y);
}

+ (CGFloat) distancePoint: (CGPoint) p1 toPoint: (CGPoint) p2
{
    CGFloat xDist = (p2.x - p1.x);
    CGFloat yDist = (p2.y - p1.y);
    CGFloat distance = sqrt((xDist * xDist) + (yDist * yDist));
    
    return distance;
}

+ (CGRect) rect: (CGRect) rect alignVerticalWith: (CGRect) outerRect round: (BOOL) round
{
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;
    
    CGFloat x = rect.origin.x;
    CGFloat y = outerRect.origin.y + (outerHeight - innerHeight) / 2.0;
    if (round)
        y = roundf(y);
    
    return [RectUtil setPositionOf: rect x: x y: y];
}

+ (CGRect) rect: (CGRect) rect centerAlignWith: (CGRect) outerRect round: (BOOL) round
{
    CGFloat innerHeight = rect.size.height;
    CGFloat outerHeight = outerRect.size.height;

    CGFloat innerWidth = rect.size.width;
    CGFloat outerWidth = outerRect.size.width;

    CGFloat x = outerRect.origin.x + (outerWidth - innerWidth) / 2.0;
    CGFloat y = outerRect.origin.y + (outerHeight - innerHeight) / 2.0;
    if (round) {
        x = roundf(x);
        y = roundf(y);
    }
    
    return [RectUtil setPositionOf: rect x: x y: y];
}

@end
