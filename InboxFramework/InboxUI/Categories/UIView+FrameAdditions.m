//
//  UIViewAdditions.m
//  PAR Works iOS SDK
//
//  Copyright 2013 PAR Works, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//



#import "UIView+FrameAdditions.h"

@implementation UIView (FrameAdditions)

- (void)in_setFrameY:(float)y
{
    CGRect frame = [self frame];
    frame.origin.y = y;
    [self setFrame: frame];
}

- (void)in_setFrameX:(float)x
{
    CGRect frame = [self frame];
    frame.origin.x = x;
    [self setFrame: frame];
}

- (void)in_shiftFrame:(CGPoint)offset
{
    CGRect frame = [self frame];
    [self setFrame: CGRectMake(frame.origin.x + offset.x, frame.origin.y + offset.y, frame.size.width, frame.size.height)];
}

- (void)in_setFrameOrigin:(CGPoint)origin
{
    CGRect frame = [self frame];
    [self setFrame: CGRectMake(origin.x, origin.y, frame.size.width, frame.size.height)];
}

- (void)in_setFrameSize:(CGSize)size
{
    CGRect frame = [self frame];
    [self setFrame: CGRectMake(frame.origin.x, frame.origin.y, size.width, size.height)];
}

- (void)in_setFrameCenter:(CGPoint)p
{
    CGRect frame = [self frame];
    [self setFrame: CGRectMake(p.x - frame.size.width / 2, p.y - frame.size.height / 2, frame.size.width, frame.size.height)];
}

- (void)in_setFrameWidth:(float)w
{    
    CGRect frame = [self frame];
    frame.size.width = w;
    [self setFrame: frame];
}

- (void)in_setFrameHeight:(float)h
{    
    CGRect frame = [self frame];
    frame.size.height = h;
    [self setFrame: frame];
}

- (CGPoint)in_topRight
{
    return CGPointMake([self frame].origin.x + [self frame].size.width, [self frame].origin.y);
}

- (CGPoint)in_bottomRight
{
    return CGPointMake([self frame].origin.x + [self frame].size.width, [self frame].origin.y + [self frame].size.height);
}

- (CGPoint)in_bottomLeft
{
    return CGPointMake([self frame].origin.x, [self frame].origin.y + [self frame].size.height);
}

- (id)viewAncestorOfClass:(Class)klass
{
    if ([[self superview] isKindOfClass: klass])
        return [self superview];
    else
        return [[self superview] viewAncestorOfClass: klass];
}

@end
