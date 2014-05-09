//
//  FMResultSet+INModelQueries.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "FMResultSet+INModelQueries.h"
#import "INModelObject+Uniquing.h"

@implementation FMResultSet (INModelQueries)

- (INModelObject *)nextModelOfClass:(Class)klass
{
	if ([klass isSubclassOfClass:[INModelObject class]] == NO)
		@throw @"Can only be used with subclasses of INModelObject";

	[self next];

	if (![self hasAnotherRow])
		return nil;

	NSError * err = nil;
	NSData * jsonData = [self dataNoCopyForColumn:@"data"];
	NSDictionary * json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&err];

	if (json && !err) {
		BOOL created = NO;
		INModelObject * model = [klass attachedInstanceMatchingID: json[@"id"] createIfNecessary:YES didCreate: &created];
		if (created) {
			[model updateWithResourceDictionary: json];
			[model setup];
		}
		return model;

	} else {
		return nil;
	}
}

@end
