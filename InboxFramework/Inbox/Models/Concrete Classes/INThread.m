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
	return [[INMessageProvider alloc] initWithThreadID: [self ID] andNamespaceID:[self namespaceID]];
}

- (INMessage*)currentDraft
{
    // TODO may not always get the right item if data is not loaded!
    // This should be replaced by a draft_id on the thread that points to the
    // draft message at all times.
    
    if (![self hasTagWithID: INTagIDDraft])
        return nil;
    
    INMessage * __block draft = nil;
    [[INDatabaseManager shared] selectModelsOfClassSync:[INMessage class] withQuery:@"SELECT * FROM INMessage WHERE thread = :thread" andParameters:@{@"thread":[self ID]} andCallback:^(NSArray *objects) {
        for (INMessage * message in objects)
            if ([message isDraft])
                draft = message;
    }];
    
    if (!draft)
        draft = [INMessage instanceWithID:[[self messageIDs] lastObject] inNamespaceID:[self namespaceID]];
    
    return draft;
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
