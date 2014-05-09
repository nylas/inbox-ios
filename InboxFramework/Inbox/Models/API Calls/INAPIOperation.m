//
//  INAPICall.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPIOperation.h"
#import "INAPIManager.h"
#import "INModelObject.h"
#import "INModelObject+Uniquing.h"
#import "INDatabaseManager.h"

@implementation INAPIOperation

+ (INAPIOperation *)operationWithMethod:(NSString *)method forModel:(INModelObject *)model
{
	NSString * url = [[NSURL URLWithString:[model resourceAPIPath] relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	NSError * error = nil;
	NSURLRequest * request = [[[INAPIManager shared] requestSerializer] requestWithMethod:method URLString:url parameters:[model resourceDictionary] error:&error];

	if (!error) {
		INAPIOperation * operation = [[INAPIOperation alloc] initWithRequest:request];
		[operation setModelClass: [model class]];
		return operation;
	}
	else {
		NSLog(@"Unable to create INAPIOperation for saving %@. %@", [model description], [error localizedDescription]);
		return nil;
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		self.modelClass = NSClassFromString([aDecoder decodeObjectForKey: @"modelClass"]);
		self.modelRollbackDictionary = [aDecoder decodeObjectForKey: @"modelRollbackDictionary"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:NSStringFromClass(_modelClass) forKey:@"modelClass"];
	[aCoder encodeObject:_modelRollbackDictionary forKey:@"modelRollbackDictionary"];
}

- (BOOL)invalidatesPreviousQueuedOperation:(AFHTTPRequestOperation *)other
{
	BOOL bothPut = ([[[other request] HTTPMethod] isEqualToString:@"PUT"] && [[[self request] HTTPMethod] isEqualToString:@"PUT"]);
	BOOL bothSamePath = [[[other request] URL] isEqual:[[self request] URL]];

	if (bothPut && bothSamePath)
		return YES;

	return NO;
}

- (void)rollback
{
	if (!_modelRollbackDictionary)
		return;
		
	INModelObject * model = [_modelClass instanceWithID: _modelRollbackDictionary[@"id"]];
	[model updateWithResourceDictionary: _modelRollbackDictionary];
	[[INDatabaseManager shared] persistModel: model];
}

@end
