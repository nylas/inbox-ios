//
//  INNamespace.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INNamespace.h"
#import "INLabel.h"
#import "INContact.h"
#import "INThreadProvider.h"
#import "INThread.h"

@implementation INNamespace

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
	 @"emailAddress": @"email_address",
 	 @"provider": @"provider",
	 @"status": @"status",
	 @"scope": @"scope",
	 @"lastSync": @"last_sync"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"n";
}

- (NSString *)resourceAPIPath
{
	return [NSString stringWithFormat:@"/n/%@", self.ID];
}

- (INModelProvider *)newContactsProvider
{
	return [[INModelProvider alloc] initWithClass:[INContact class] andNamespaceID:[self ID] andUnderlyingPredicate:nil];
}

- (INModelProvider *)newThreadsProvider
{
	return [[INThreadProvider alloc] initWithNamespaceID: [self ID]];
}

@end
