//
//  INThreadProvider.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThreadProvider.h"
#import "INModelProvider+Private.h"
#import "INAPIManager.h"
#import "INThread.h"
#import "INTag.h"
#import "INModelResponseSerializer.h"
#import "INPredicateToQueryParamConverter.h"

@implementation INThreadProvider

- (id)initWithNamespaceID:(NSString *)namespaceID
{
	self = [super initWithClass:[INThread class] andNamespaceID:namespaceID andUnderlyingPredicate:nil];
	if (self) {
	}
	return self;
}

- (NSDictionary *)queryParamsForPredicate:(NSPredicate*)predicate
{
	INPredicateToQueryParamConverter * converter = [[INPredicateToQueryParamConverter alloc] init];
	[converter setKeysToParamsTable: @{@"to": @"to", @"from": @"from", @"cc": @"cc", @"bcc": @"bcc", @"threadID": @"thread", @"label": @"label"}];

	NSMutableDictionary * params = [[converter paramsForPredicate: predicate] mutableCopy];
    [params addEntriesFromDictionary: [super queryParamsForPredicate: predicate]];
	return params;
}

- (void)refresh
{
	_numberOfUnreadItems = NSNotFound;
	[super refresh];
}

- (void)countUnreadItemsWithCallback:(LongBlock)callback
{
	if (_numberOfUnreadItems != NSNotFound)
        return callback(_numberOfUnreadItems);

    NSPredicate * unreadPredicate = [NSComparisonPredicate predicateWithFormat:@"ANY tagIDs = %@", INTagIDUnread];
    NSPredicate * predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[[self fetchPredicate], unreadPredicate]];
    [[INDatabaseManager shared] countModelsOfClass:[INThread class] matching:predicate withCallback:^(long count) {
        _numberOfUnreadItems = count;
        callback(_numberOfUnreadItems);
    }];
}

@end
