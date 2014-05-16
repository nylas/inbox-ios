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
#import "INMessage.h"

@implementation INAPIOperation

+ (INAPIOperation *)operationForModel:(INModelObject *)model
{
	INAPIOperation * op = [[self alloc] initWithRequest: nil];
    [op setModel: model];
    return op;
}

- (NSURLRequest*)buildRequest
{
    // overloaded in subclasses
    return nil;
}

- (void)start
{
    self.request = [self buildRequest];
    [super start];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
        Class modelClass = NSClassFromString([aDecoder decodeObjectForKey: @"modelClass"]);
        NSString * modelID = [aDecoder decodeObjectForKey: @"modelID"];
		self.model = [modelClass instanceWithID: modelID];
		self.modelRollbackDictionary = [aDecoder decodeObjectForKey: @"modelRollbackDictionary"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];

	[aCoder encodeObject:NSStringFromClass([_model class]) forKey:@"modelClass"];
    [aCoder encodeObject:[_model ID] forKey:@"modelID"];
    if (_modelRollbackDictionary)
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
		
	[_model updateWithResourceDictionary: _modelRollbackDictionary];
	[[INDatabaseManager shared] persistModel: _model];
}

@end


@implementation INAPISaveDraftOperation : INAPIOperation

- (NSURLRequest *)buildRequest
{
	NSError * error = nil;
    NSString * path = [NSString stringWithFormat:@"/n/%@/create_draft", [self.model namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:[self.model resourceDictionary] error:&error];
}

@end

@implementation INAPIAddRemoveTagsOperation : INAPIOperation

- (NSURLRequest *)buildRequest
{
	NSError * error = nil;
    NSString * path = [NSString stringWithFormat:@"/n/%@/create_draft", [self.model namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:[self.model resourceDictionary] error:&error];
}

@end

