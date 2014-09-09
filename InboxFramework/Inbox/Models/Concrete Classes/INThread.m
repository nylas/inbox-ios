//
//  INThread.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread.h"
#import "INTag.h"
#import "INAddRemoveTagsTask.h"

@implementation INThread

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];

	[mapping addEntriesFromDictionary:@{
		@"subject": @"subject",
		@"participants": @"participants",
		@"lastMessageDate": @"last_message_timestamp",
		@"messageIDs": @"message_ids",
        @"draftIDs": @"draft_ids",
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

- (INMessageProvider*)newMessageProvider
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
	INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
    [[task tagIDsToRemove] addObject: INTagIDInbox];
    [[task tagIDsToAdd] addObject: INTagIDArchive];
    [[INAPIManager shared] queueTask: task];
}

- (void)unarchive
{
	INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
    [[task tagIDsToRemove] addObject: INTagIDArchive];
    [[task tagIDsToAdd] addObject: INTagIDInbox];
    [[INAPIManager shared] queueTask: task];
}

- (void)star
{
	INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
    [[task tagIDsToAdd] addObject: INTagIDStarred];
    [[INAPIManager shared] queueTask: task];
}

- (void)unstar
{
	INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
    [[task tagIDsToRemove] addObject: INTagIDStarred];
    [[INAPIManager shared] queueTask: task];
}

- (void)markAsRead
{
    if ([self hasTagWithID: INTagIDUnread]) {
		INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
		[[task tagIDsToRemove] addObject: INTagIDUnread];
		[[INAPIManager shared] queueTask: task];
    }
}

- (void)markAsSeen
{
    if ([self hasTagWithID: INTagIDUnseen]) {
		INAddRemoveTagsTask * task = [INAddRemoveTagsTask operationForModel: self];
		[[task tagIDsToRemove] addObject: INTagIDUnseen];
		[[INAPIManager shared] queueTask: task];
    }
}

@end
