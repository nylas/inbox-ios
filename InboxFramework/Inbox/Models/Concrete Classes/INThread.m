//
//  INThread.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread.h"
#import "INMessageProvider.h"
#import "INTag.h"

@implementation INThread

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];

	[mapping addEntriesFromDictionary:@{
		@"subject": @"subject",
		@"participants": @"participants",
		@"lastMessageDate": @"last_message_timestamp",
		@"messageIDs": @"messages",
		@"tagObjects": @"tags",
		@"snippet": @"snippet"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"threads";
}

- (NSArray*)tags
{
	NSMutableArray * tags = [NSMutableArray array];
	for (NSString * ID in [self tagIDs])
		[tags addObject: [INTag tagWithID: ID]];
	return tags;
}

- (NSArray*)tagIDs
{
    return [_tagObjects valueForKey: @"id"];
}

- (BOOL)hasTagWithID:(NSString*)ID
{
	return [[self tagIDs] containsObject: ID];
}

- (INModelProvider*)newMessageProvider
{
	return [[INMessageProvider alloc] initWithThreadID: [self ID] andNamespaceID:[self namespaceID]];
}

- (INMessage*)currentDraft
{
    return [INMessage instanceWithID:[[self messageIDs] lastObject] inNamespaceID:[self namespaceID]];
}

#pragma mark Database

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"lastMessageDate", @"subject"]];
}

+ (NSArray *)databaseJoinTableProperties
{
	return @[@"tagIDs"];
}

@end
