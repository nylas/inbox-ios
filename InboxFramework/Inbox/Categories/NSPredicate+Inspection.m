//
//  NSPredicate+Inspection.m
//  BigSur
//
//  Created by Ben Gotow on 5/1/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "NSPredicate+Inspection.h"

@implementation NSPredicate (Inspection)

- (BOOL)containsOrMatches:(NSString*)expression
{
	NSMutableString * descriptions = [NSMutableString string];
	if ([self isKindOfClass: [NSCompoundPredicate class]]) {
		for (NSPredicate * sub in [(NSCompoundPredicate*)self subpredicates])
			[descriptions appendString: [sub description]];
	} else {
		[descriptions appendString: [self description]];
	}

	if ([descriptions rangeOfString: expression].location != NSNotFound)
		return YES;
	return NO;
}
@end
