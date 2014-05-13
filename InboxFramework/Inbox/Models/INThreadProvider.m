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
#import "INModelArrayResponseSerializer.h"
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

	// currently not useful, because the sort order is on item ID
//	[params setObject:@(self.itemRange.location) forKey:@"offset"];
	[params setObject:@(10000) forKey:@"limit"];
	
	return params;
}

- (void)refresh
{
	_numberOfUnreadItems = NSNotFound;
	[super refresh];
}

- (long)numberOfUnreadItems
{
	if (_numberOfUnreadItems == NSNotFound) {
		NSPredicate * unreadPredicate = [NSComparisonPredicate predicateWithFormat:@"ANY tagIDs = %@", INTagIDUnread];
		NSPredicate * predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[[self fetchPredicate], unreadPredicate]];
		_numberOfUnreadItems = [[INDatabaseManager shared] countModelsOfClass:[INThread class] matching:predicate];
	}
	return _numberOfUnreadItems;
}

@end
