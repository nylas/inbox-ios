//
//  INThread.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread.h"
#import "INMessageProvider.h"
#import "INArchiveThreadTask.h"
#import "INUnarchiveThreadTask.h"
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
        @"draftIDs": @"drafts",
		@"tagIDs": @"tags",
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

- (void)updateWithResourceDictionary:(NSDictionary *)dict
{
    [super updateWithResourceDictionary:dict];
    if ([[[self tagIDs] firstObject] isKindOfClass: [NSDictionary class]])
        _tagIDs = [_tagIDs valueForKey: @"id"];
}

- (void)setTagIDs:(NSArray *)tagIDs
{
    NSMutableArray * unique = [NSMutableArray array];
    for (NSString * ID in tagIDs)
        if (![unique containsObject: ID])
            [unique addObject: ID];
    _tagIDs = unique;
}

- (BOOL)hasTagWithID:(NSString*)ID
{
	return [[self tagIDs] containsObject: ID];
}

- (INModelProvider*)newMessageProvider
{
	return [[INMessageProvider alloc] initForMessagesInThread: [self ID] andNamespaceID:[self namespaceID]];
}

- (INModelProvider*)newDraftProvider
{
	return [[INMessageProvider alloc] initForDraftsInThread:[self ID] andNamespaceID:[self namespaceID]];
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

#pragma mark Operations on Threads

- (void)archive
{
	INArchiveThreadTask * archive = [INArchiveThreadTask operationForModel: self];
    [[INAPIManager shared] queueTask: archive];
}

- (void)unarchive
{
	INUnarchiveThreadTask * unarchive = [INUnarchiveThreadTask operationForModel: self];
    [[INAPIManager shared] queueTask: unarchive];
}

@end
