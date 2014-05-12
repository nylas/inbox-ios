//
//  INThread.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread.h"
#import "INMessageProvider.h"

@implementation INThread

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];

	[mapping addEntriesFromDictionary:@{
		@"subject": @"subject",
		@"participants": @"participants",
		@"lastMessageDate": @"last_message_timestamp",
		@"messageIDs": @"messages",
		@"snippet": @"snippet",
		@"unread":@"unread"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"threads";
}

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"lastMessageDate", @"subject", @"unread"]];
}

- (INModelProvider*)newMessageProvider
{
	return [[INMessageProvider alloc] initWithThreadID: [self ID] andNamespaceID:[self namespaceID]];
}


@end
