//
//  INMessageProvider.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessageProvider.h"
#import "INModelProvider+Private.h"
#import "INPredicateToQueryParamConverter.h"
#import "INThread.h"

@implementation INMessageProvider

- (id)initWithThreadID:(NSString *)threadID andNamespaceID:(NSString*)namespaceID
{
	NSPredicate * threadPredicate = [NSComparisonPredicate predicateWithFormat:@"threadID = %@", threadID];
	self = [super initWithClass:[INMessage class] andNamespaceID:namespaceID andUnderlyingPredicate:threadPredicate];
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


@end
