//
//  INModelObject.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelObject+Uniquing.h"
#import "INAPIManager.h"
#import "INAPITask.h"
#import "NSObject+Properties.h"
#import "NSString+FormatConversion.h"
#import "NSDictionary+FormatConversion.h"
#import "INPredicateToSQLConverter.h"
#import "INDatabaseManager.h"
#import "INModelResponseSerializer.h"
#import "INNamespace.h"

@implementation INModelObject

#pragma Getting Instances

+ (id)instanceWithID:(NSString*)ID inNamespaceID:(NSString*)namespaceID
{
	// do we have an instance in memory that matches this ID?
	INModelObject __block * match = [self attachedInstanceMatchingID: ID createIfNecessary:NO didCreate:NULL];

	// do we have an instance in the local cache?
	if (!match)
		match = [[INDatabaseManager shared] selectModelOfClass: self withID: ID];
			
	// this object is not available. Return a stub that they can -reload if they want to.
	if (!match) {
		match = [[self alloc] init];
		[match setID: ID];
        [match setNamespaceID: namespaceID];
	}
	
	return match;
}

#pragma NSCoding Support

- (id)init
{
    self = [super init];
    if (self) {
        [self setID: [NSString generateUUIDWithExtension: @"-selfdefined"]];
		[self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];

	if (self) {
		NSDictionary * mapping = [[self class] resourceMapping];
		[self setEachPropertyInSet:[mapping allKeys] withValueProvider:^BOOL (id key, NSObject ** value, NSString * type) {
			if (![aDecoder containsValueForKey:key])
				return NO;

			*value = [aDecoder decodeObjectForKey:key];
			return YES;
		}];

        _isDataAvailable = YES;
        [self setup];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	NSDictionary * mapping = [[self class] resourceMapping];

	[self getEachPropertyInSet:[mapping allKeys] andInvoke:^(id key, NSString * type, id value) {
		BOOL encodable = [value respondsToSelector:@selector(encodeWithCoder:)];

		if (encodable)
			[aCoder encodeObject:value forKey:key];
		else if (value)
			NSLog(@"Value of %@ (%@) does not comply to NSCoding.", key, [value description]);
	}];
}

- (BOOL)isUnsynced
{
    return [self.ID hasSuffix:@"-selfdefined"];
}

- (BOOL)isDataAvailable
{
    return _isDataAvailable;
}

- (INNamespace*)namespace
{
    return [INNamespace instanceWithID:[self namespaceID] inNamespaceID:nil];
}

#pragma mark Resource Representation

- (NSMutableDictionary *)resourceDictionary
{
	NSDictionary * mapping = [[self class] resourceMapping];
	NSMutableDictionary * json = [NSMutableDictionary dictionary];

	[self getEachPropertyInSet:[mapping allKeys] andInvoke:^(id key, NSString * type, id value) {
		if ([value isKindOfClass:[INModelObject class]])
			return;

		if ([value isKindOfClass:[NSDate class]])
			value = [NSNumber numberWithDouble: [(NSDate*)value timeIntervalSince1970]];
			
		NSString * jsonKey = [mapping objectForKey:key];

		if (value)
			[json setObject:value forKey:jsonKey];
		else
			[json setObject:[NSNull null] forKey:jsonKey];
	}];

	return json;
}

- (BOOL)differentFromResourceDictionary:(NSDictionary *)json
{
	if ([json isKindOfClass:[NSDictionary class]] == NO)
		NSAssert(false, @"differentFromResourceDictionary called with json that is not a dictionary");

	NSDictionary * mapping = [[self class] resourceMapping];
	BOOL __block different = NO;
	
	[self getEachPropertyInSet:[mapping allKeys] andInvoke:^(id key, NSString * type, id value) {
		NSString * jsonKey = [mapping objectForKey:key];
		if ([json objectForKey:jsonKey]) {
			id valueInJSON = [json objectForKey:jsonKey asType:type];
			
			BOOL bothNil = ((valueInJSON == nil) && (value == nil));
			BOOL bothEqual = [valueInJSON isEqual: value];
			
			if (!(bothNil || bothEqual))
				different = YES;
		}
	}];
	
	return different;
}

- (void)updateWithResourceDictionary:(NSDictionary *)json
{
	NSAssert([NSThread isMainThread], @"INModelObjects should not be mutated from background threads.");
	
	if ([json isKindOfClass:[NSDictionary class]] == NO)
		NSAssert(false, @"updateWithResourceDictionary called with json that is not a dictionary");
	
	NSDictionary * mapping = [[self class] resourceMapping];
	NSArray * properties = [mapping allKeys];
	
	[self setEachPropertyInSet:properties withValueProvider:^BOOL (id key, NSObject ** value, NSString * type) {
		NSString * jsonKey = [mapping objectForKey:key];
		if (![json objectForKey:jsonKey])
			return NO;

		*value = [json objectForKey:jsonKey asType: type];
		return YES;
	}];

    _isDataAvailable = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:INModelObjectChangedNotification object:self];
    });
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ <%p> %@", NSStringFromClass([self class]), self, [self resourceDictionary]];
}


#pragma Loading and Saving

- (void)reload:(ErrorBlock)callback
{
	[[INAPIManager shared].AF GET:[self resourceAPIPath] parameters:@{} success:^(AFHTTPRequestOperation * operation, id responseObject) {
		[self updateWithResourceDictionary:responseObject];
		[[INDatabaseManager shared] persistModel:self];
		if (callback)
			callback(YES, nil);
	} failure:^(AFHTTPRequestOperation * operation, NSError * error) {
		if (callback)
			callback(NO, error);
	}];
}


#pragma Override Points & Subclassing Support

+ (NSMutableDictionary *)resourceMapping
{
	return [@{@"ID": @"id",
              @"namespaceID": @"namespace_id",
              @"createdAt": @"created_at",
              @"updatedAt": @"updated_at",
              @"lastAccessedAt": @"last_accessed_at"} mutableCopy];
}

+ (NSString *)resourceAPIName
{
	NSAssert(false, @"This class does not provide a resourceAPIName. Subclasses should provide one.");
	return nil;
}

+ (NSString *)databaseTableName
{
	return NSStringFromClass(self);
}

+ (NSArray *)databaseIndexProperties
{
	return @[@"ID", @"namespaceID", @"lastAccessedAt"];
}

+ (NSArray *)databaseJoinTableProperties
{
	return @[];
}

- (NSString *)resourceAPIPath
{
	return [NSString stringWithFormat: @"/n/%@/%@/%@", [self namespaceID], [[self class] resourceAPIName], [self ID]];
}

- (void)setup
{
	// override point for subclasses
}

+ (void)afterDatabaseSetup:(FMDatabase*)db
{
	// override point for subclasses
}

- (void)beforePersist:(FMDatabase*)db
{
	// override point for subclasses
}

- (void)afterPersist:(FMDatabase*)db
{
	// override point for subclasses
}

- (void)beforeUnpersist:(FMDatabase*)db
{
	// override point for subclasses
}

- (void)afterUnpersist:(FMDatabase*)db
{
	
}

#pragma mark Getting and Setting Resource Properties

- (void)getEachPropertyInSet:(NSArray *)properties andInvoke:(void (^)(id key, NSString * type, id value))block
{
	for (NSString * key in properties) {
		NSString * type = [self typeOfPropertyNamed:key];
		id val = [self valueForKey:key];

		block(key, type, val);
	}
}

- (void)setEachPropertyInSet:(NSArray *)properties withValueProvider:(BOOL (^)(id key, NSObject ** value, NSString * type))block
{
	for (NSString * key in properties) {
		NSString * type = [self typeOfPropertyNamed:key];
		NSObject * value = [self valueForKey:key];

		if (block(key, &value, type)) {
			if ([value isKindOfClass:[NSNull class]]) {
				if ([type isEqualToString:@"Ti"] || [type isEqualToString:@"Tf"])
					[self setValue:[NSNumber numberWithInt:0] forKey:key];
				else if ([type isEqualToString:@"Tc"])
					value = [NSNumber numberWithBool:NO];
				else
					[self setValue:nil forKey:key];
			}
			else {
				if ([type isEqualToString:@"T@\"NSString\""] && [value isKindOfClass:[NSNumber class]])
					value = [(NSNumber *)value stringValue];

				if ([type isEqualToString:@"Tc"])
					if ([value isKindOfClass:[NSString class]])
						value = [NSNumber numberWithChar:[(NSString *)value characterAtIndex : 0]];
				[self setValue:value forKey:key];
			}
		}
	}
}

@end
