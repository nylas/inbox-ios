//
//  INAPICall.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelChange.h"
#import "INAPIManager.h"
#import "INModelObject.h"
#import "INModelObject+Uniquing.h"
#import "INDatabaseManager.h"
#import "NSString+FormatConversion.h"
#import "INMessage.h"
#import "INThread.h"
#import "INModelResponseSerializer.h"
#import "INTag.h"


@implementation INModelChange

+ (instancetype)operationForModel:(INModelObject *)model
{
    return [[self alloc] initWithModel: model];
}

- (id)initWithModel:(INModelObject*)model
{
	self = [super init];
	if (self) {
        _model = model;
        _data = [NSMutableDictionary dictionary];
        _ID = [NSString generateUUIDWithExtension: NSStringFromClass([self class])];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if (self) {
        Class modelClass = NSClassFromString([aDecoder decodeObjectForKey: @"modelClass"]);
        NSString * modelID = [aDecoder decodeObjectForKey: @"modelID"];
		_model = [modelClass instanceWithID: modelID];
        _ID = [aDecoder decodeObjectForKey:@"ID"];
        _data = [aDecoder decodeObjectForKey: @"data"];
        _dependencies = [aDecoder decodeObjectForKey:@"dependencies"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:NSStringFromClass([_model class]) forKey:@"modelClass"];
    [aCoder encodeObject:[_model ID] forKey:@"modelID"];
    [aCoder encodeObject:_ID forKey:@"ID"];
    [aCoder encodeObject:_data forKey:@"data"];
    [aCoder encodeObject:_dependencies forKey:@"dependencies"];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ on %@ <%p>\r     - in progress: %d\r     - dependencies: %@", NSStringFromClass([self class]), NSStringFromClass([[self model] class]), self.model, _inProgress, [_dependencies componentsJoinedByString:@", "]];
}

- (BOOL)dependentOnChangesIn:(NSArray*)others
{
    for (INModelChange * change in others)
        if ([_dependencies containsObject: [change ID]])
            return YES;
    return NO;
}

- (void)addDependency:(INModelChange*)otherChange
{
    if (!_dependencies)
        _dependencies = [NSMutableArray array];
    [_dependencies addObject: [otherChange ID]];
}

- (void)startWithCallback:(CallbackBlock)callback
{
    AFHTTPRequestOperation * op = [[INAPIManager shared] HTTPRequestOperationWithRequest:[self buildRequest] success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self handleSuccess: operation withResponse: responseObject];
        [self setInProgress: NO];
        callback(self, YES);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleFailure:operation withError:error];
        [self setInProgress: NO];

        NSURLRequest * request = [operation request];
        NSInteger code = [[operation response] statusCode];

        if ((code == 0) || (code >= 500) || (code == 305) || (code == 407) || (code == 408)) {
            // no connection, server error / unavailable, use proxy, proxy auth required, request timeout
            // We received an error that indicates future API calls will fail too.
            // Pause the operations queue and add this operation to it again.
            callback(self, NO);
        } else {
            // For some reason, we reached inbox and it rejected this operation. To maintain the consistency
            // of our cache, roll back the operation and we DO NOT try to send it again.
            NSLog(@"The server rejected %@ %@. Response code %d. To maintain the cache consistency, the update is being rolled back.", [request HTTPMethod], [request URL], code);
            [self rollbackLocally];
            callback(self, YES);
        }
    }];
    
    [self setInProgress: YES];
    [[[INAPIManager shared] operationQueue] addOperation: op];
}

#pragma Subclassing Hooks

- (NSURLRequest*)buildRequest
{
    return nil;
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    
}

- (void)handleFailure:(AFHTTPRequestOperation *)operation withError:(NSError*)error
{
    
}

- (void)applyLocally
{
    
}

- (void)rollbackLocally
{
    
}

@end

@implementation INAPISaveOperation

- (NSURLRequest *)buildRequest
{
	NSError * error = nil;
    NSString * url = [[NSURL URLWithString:[[self model] resourceAPIPath] relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"PUT" URLString:url parameters:[self.model resourceDictionary] error:&error];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    if ([responseObject isKindOfClass: [NSDictionary class]])
        [[self model] updateWithResourceDictionary: responseObject];
}

- (void)applyLocally
{
    [[INDatabaseManager shared] persistModel: self.model];
}

@end


