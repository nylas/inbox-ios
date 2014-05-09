//
//  NSDictionary+FormatConversion.m
//  BigSur
//
//  Created by Ben Gotow on 5/1/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "NSDictionary+FormatConversion.h"
#import "NSString+FormatConversion.h"
#import "INModelObject.h"

@implementation NSDictionary (FormatConversion)

- (id)objectForKey:(id)key asType:(NSString*)type
{
	id value = [self objectForKey:key];
	
	NSAssert(value != nil, @"You cannot call -objectForKey:asType: for a nonexistent key, because nonexistence cannot be distinguished from NSNull=nil in the return value.");
	
	if ([[self objectForKey:key] isKindOfClass:[NSNull class]]) {
		return nil;
	}
	
	if ([type isEqualToString:@"float"]) {
		return [NSNumber numberWithFloat:[value floatValue]];
	}
	else if ([type isEqualToString:@"int"]) {
		return [NSNumber numberWithInt:[value intValue]];
	}
	else if ([type isEqualToString:@"T@\"NSString\""]) {
		if ([value isKindOfClass:[NSNumber class]])
			return [value stringValue];
		else if ([value isKindOfClass:[NSString class]])
			return value;
		else
			return [value stringValue];
	}
	else if ([type isEqualToString:@"T@\"NSDate\""]) {
		return [NSDate dateWithTimeIntervalSince1970: [value doubleValue]];
	}
	
	return value;
}

@end
