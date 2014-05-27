//
//  INModelArrayResponseSerializer.m
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelResponseSerializer.h"
#import "INModelObject.h"
#import "INModelObject+Uniquing.h"
#import "INDatabaseManager.h"
#import "NSError+InboxErrors.h"


@implementation INModelResponseSerializer

- (id)initWithModelClass:(Class)klass
{
	self = [super init];

	if (self) {
		_modelClass = klass;
		self.readingOptions = NSJSONReadingAllowFragments;
	}
	return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError * __autoreleasing *)error
{
	id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject && error)
        return nil;
    
	BOOL badJSONClass = ([responseObject isKindOfClass:[NSArray class]] == NO);
	BOOL badAPIResponse = ([responseObject isKindOfClass: [NSDictionary class]] && [responseObject[@"type"] isEqualToString: @"api_error"]);
	
	if (badAPIResponse) {
		*error = [NSError inboxErrorWithDescription: responseObject[@"message"]];
		return nil;
	}
	
	if (badJSONClass) {
		*error = [NSError inboxErrorWithDescription: @"The JSON object returned was not an NSArray"];
		return nil;
	}

	NSMutableArray * models = [NSMutableArray array];
	NSMutableArray * modifiedOrUnloadedModels = [NSMutableArray array];
	
	dispatch_sync(dispatch_get_main_queue(), ^{
		for (NSDictionary * modelDictionary in responseObject) {
			BOOL created = NO;
			INModelObject * object = [_modelClass attachedInstanceMatchingID: modelDictionary[@"id"] createIfNecessary: YES didCreate: &created];
			
			if (created) {
				// If we don't have a copy of the object in memory, inflate one and write it
				// to the database. Note that these will probably be freed shortly.
				[object updateWithResourceDictionary:modelDictionary];
				[object setup];
				[modifiedOrUnloadedModels addObject: object];

			} else {
				// If we have a copy of the object in memory already, let's be smart. Only apply
				// changes to the model if necessary. This prevents unnecessary notifications from
				// being fired, animations in the interface, etc.
				if ([object differentFromResourceDictionary: modelDictionary]) {
					[object updateWithResourceDictionary:modelDictionary];
					[modifiedOrUnloadedModels addObject: object];
				}
			}
			
			[models addObject:object];
		}
	});

	// Save models to our local database. The database will notify it's
	// observers that these models have been saved, and INModelProviders
	// will automatically compute alterations, triggering UI updates.
	[[INDatabaseManager shared] persistModels: modifiedOrUnloadedModels];
	return models;
}

@end

