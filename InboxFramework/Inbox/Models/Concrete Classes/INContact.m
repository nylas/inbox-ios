//
//  INContact.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INContact.h"

@implementation INContact

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];

	[mapping addEntriesFromDictionary:@{
		@"source": @"source",
		@"name": @"name",
		@"providerName": @"provider_name",
		@"emailAddress": @"email_address",
		@"accountID": @"account_id",
		@"UID": @"uid"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"contacts";
}

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"name", @"emailAddress", @"accountID"]];
}

- (void)setup
{
}


@end
