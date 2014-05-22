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
        NSString * modelNamespaceID = [aDecoder decodeObjectForKey: @"modelNamespaceID"];
		_model = [modelClass instanceWithID: modelID inNamespaceID: modelNamespaceID];

        _ID = [aDecoder decodeObjectForKey:@"ID"];
        _data = [aDecoder decodeObjectForKey: @"data"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:NSStringFromClass([_model class]) forKey:@"modelClass"];
    [aCoder encodeObject:[_model ID] forKey:@"modelID"];
    [aCoder encodeObject:[_model namespaceID] forKey:@"modelNamespaceID"];
    [aCoder encodeObject:_ID forKey:@"ID"];
    [aCoder encodeObject:_data forKey:@"data"];
}

- (void)setPercentComplete:(float)percentComplete
{
	_percentComplete = percentComplete;
	[[NSNotificationCenter defaultCenter] postNotificationName:INModelChangeUploadProgressNotification object:self];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ on %@ <%p>", NSStringFromClass([self class]), NSStringFromClass([[self model] class]), self.model];
}

- (BOOL)canCancelPendingChange:(INModelChange*)other
{
    return NO;
}

- (BOOL)canStartAfterChange:(INModelChange*)other
{
    return YES;
}

- (NSArray*)dependenciesIn:(NSArray*)others
{
	return nil;
}

- (void)applyLocally
{
    
}

- (void)applyRemotelyWithCallback:(CallbackBlock)callback
{
    AFHTTPRequestOperation * op = [[INAPIManager shared] HTTPRequestOperationWithRequest:[self buildAPIRequest] success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self handleSuccess: operation withResponse: responseObject];
        [self setInProgress: NO];
        callback(self, YES);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleFailure:operation withError:error];
        [self setInProgress: NO];
		[self setPercentComplete: 0];

        NSURLRequest * request = [operation request];
        NSInteger code = [[operation response] statusCode];

        if ((code == 0) || (code >= 500) || (code == 305) || (code == 407) || (code == 408) || (code == 404) || (code == 405)) {
            // no connection, server error / unavailable, use proxy, proxy auth required, request timeout
            // We received an error that indicates future API calls will fail too.
            // Pause the operations queue and add this operation to it again.
            NSLog(@"The server returned response code %d for %@ %@. Change %@ failed.", code, [request HTTPMethod], [request URL], NSStringFromClass([self class]));
            callback(self, NO);
        } else {
            // For some reason, we reached inbox and it rejected this operation. To maintain the consistency
            // of our cache, roll back the operation and we DO NOT try to send it again.
            NSLog(@"The server rejected %@ %@. Response code %d. To maintain the cache consistency, the update is being rolled back.", [request HTTPMethod], [request URL], code);
            [self rollbackLocally];
            callback(self, YES);
        }
    }];
    
	[op setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		[self setPercentComplete: (double)totalBytesWritten / (double)totalBytesExpectedToWrite];
	}];

    [self setInProgress: YES];
	[self setPercentComplete: 0.01];
    [[[INAPIManager shared] operationQueue] addOperation: op];
}

- (void)rollbackLocally
{
    
}

- (NSURLRequest*)buildAPIRequest
{
    return nil;
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    
}

- (void)handleFailure:(AFHTTPRequestOperation *)operation withError:(NSError*)error
{
    
}

@end


