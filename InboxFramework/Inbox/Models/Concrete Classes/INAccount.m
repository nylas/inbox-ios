//
//  INUser.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAccount.h"
#import "INNamespace.h"

@implementation INAccount


+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
	 @"namespaceIDs": @"namespaces",
	 @"name": @"name",
	 @"authToken": @"auth_token"
	}];
	return mapping;
}

+ (NSArray *)databaseIndexProperties
{
	return @[];
}

- (NSString*)resourceAPIPath
{
	return [NSString stringWithFormat:@"/a/%@", self.ID];
}

- (NSArray*)namespaces
{
	NSMutableArray * namespaces = [NSMutableArray array];
	for (NSString * ID in _namespaceIDs) {
		INNamespace * namespace = [INNamespace instanceWithID: ID];
		[namespaces addObject: namespace];
		
		if (![namespace emailAddress])
			[namespace reload: NULL];
	}
	return namespaces;
}

- (NSArray*)ownEmailAddresses
{
	NSMutableArray * youAddresses = [NSMutableArray array];
	INAccount * account = [[INAPIManager shared] account];
	for (INNamespace * namespace in [account namespaces]) {
		if ([namespace emailAddress])
			[youAddresses addObject:[ namespace emailAddress]];
	}
	return youAddresses;
}
@end
