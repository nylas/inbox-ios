//
//  INMessage.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INThread.h"
#import "NSString+FormatConversion.h"

@implementation INMessage


+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
 	 @"subject": @"subject",
 	 @"body": @"body",
	 @"threadID": @"thread",
	 @"date": @"date",
	 @"from": @"from",
	 @"to": @"to"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"messages";
}

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"threadID", @"subject", @"date"]];
}

- (INThread*)thread
{
    return [INThread instanceWithID: [self threadID]];
}

@end
