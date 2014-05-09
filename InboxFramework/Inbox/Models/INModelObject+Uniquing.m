//
//  INModelObject+Uniquing.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject+Uniquing.h"
#import "INDatabaseManager.h"

static NSMapTable * modelInstanceTable;

@implementation INModelObject (Uniquing)

+ (id)attachedInstanceMatchingID:(id)ID createIfNecessary:(BOOL)shouldCreate didCreate:(BOOL*)didCreate
{
	if (!modelInstanceTable)
		modelInstanceTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:1000];

	id obj = nil;
	@synchronized(modelInstanceTable) {
		obj = [modelInstanceTable objectForKey:[INModelObject attachmentKeyForClass:self ID:ID]];
		if (shouldCreate && !obj) {
			obj = [[self alloc] init];
			[obj setID: ID];
			[modelInstanceTable setObject:obj forKey:[INModelObject attachmentKeyForClass:[obj class] ID:[obj ID]]];
			if (didCreate) *didCreate = YES;
		}
	}
	return obj;
}

+ (void)attachInstance:(INModelObject *)obj
{
	NSAssert(obj, @"-attachInstance called with a null object.");
	NSAssert([obj isKindOfClass:[INModelObject class]], @"Only subclasses of INModelObject can be attached.");

	@synchronized(modelInstanceTable) {
		id existing = [INModelObject attachedInstanceMatchingID:[obj ID] createIfNecessary: NO didCreate: NULL];
		if (!existing)
			[modelInstanceTable setObject:obj forKey:[INModelObject attachmentKeyForClass:[obj class] ID:[obj ID]]];
		else if (existing != obj)
			NSAssert(false, @"Attaching an instance when another instance is already in memory for this class+ID combination. Where did this object come from?");
	}
}

+ (NSString *)attachmentKeyForClass:(Class)klass ID:(id)ID
{
	if ([ID isKindOfClass:[NSNumber class]])
		ID = [ID stringValue];

	char cString[255];
	sprintf(cString, "%p-%s", (__bridge void *)klass, [ID cStringUsingEncoding:NSUTF8StringEncoding]);
	return [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
}

- (id)detatchedCopy
{
	Class klass = [self class];
	id copy = [[klass alloc] init];

	[copy updateWithResourceDictionary:[self resourceDictionary]];
	return copy;
}

- (BOOL)isDetatched
{
	return [INModelObject attachedInstanceMatchingID:[self ID] createIfNecessary: NO didCreate: NULL] != self;
}

@end
