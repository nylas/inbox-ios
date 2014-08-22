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
	[converter setKeysToParamsTable: @{@"to": @"to", @"from": @"from", @"cc": @"cc", @"bcc": @"bcc", @"tagIDs":@"tag"}];
	[converter setKeysToLIKEParamsTable: @{@"subject": @"subject"}];
	
	NSMutableDictionary * params = [[converter paramsForPredicate: predicate] mutableCopy];
    [params addEntriesFromDictionary: [super queryParamsForPredicate: predicate]];
	
    NSSortDescriptor * descriptor = [[self itemSortDescriptors] firstObject];
    if (descriptor) {
        if (![[descriptor key] isEqualToString: @"lastMessageDate"])
            NSAssert(false, @"Sorry, the backend only supports ordering threads by `lastMessageDate`, so this provider cannot load threads.");
    }
    
    return params;
}

- (void)refresh
{
	[super refresh];
}

- (void)countUnreadItemsWithCallback:(LongBlock)callback
{
    NSPredicate * unreadPredicate = [NSComparisonPredicate predicateWithFormat:@"ANY tagIDs = %@", INTagIDUnread];
    NSPredicate * predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[[self fetchPredicate], unreadPredicate]];
    [[INDatabaseManager shared] countModelsOfClass:[INThread class] matching:predicate withCallback:^(long count) {
        callback(count);
    }];
}

@end
