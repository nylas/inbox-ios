//
//  INAPICall.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPITask.h"
#import "INAPIManager.h"
#import "INModelObject.h"
#import "INModelObject+Uniquing.h"
#import "INDatabaseManager.h"
#import "NSString+FormatConversion.h"
#import "INMessage.h"
#import "INThread.h"
#import "INModelResponseSerializer.h"
#import "INTag.h"


@implementation INAPITask

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
        _state = INAPITaskStateWaiting;
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
        _state = INAPITaskStateWaiting;
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

- (NSString*)extendedDescription
{
    NSArray * queue = [[INAPIManager shared] taskQueue];
    NSString * dependencyIDs = [[[self dependenciesIn: queue] valueForKey: @"description"] componentsJoinedByString:@"\r          "];
    NSString * stateString = @[@"waiting", @"in progress", @"finished", @"server-unreachable", @"server-rejected"][[self state]];
    return [NSString stringWithFormat: @"%@\r     - state: %@ \r     - error: %@ \r     - dependencies: %@", [self description], stateString, [self error], dependencyIDs];
}

- (void)setPercentComplete:(float)percentComplete
{
	_percentComplete = percentComplete;
	[[NSNotificationCenter defaultCenter] postNotificationName:INTaskProgressNotification object:self];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ on %@ <%p>", NSStringFromClass([self class]), NSStringFromClass([[self model] class]), self.model];
}

- (NSString*)error
{
    return _data[@"error"];
}

- (BOOL)inProgress
{
    return (_state == INAPITaskStateInProgress);
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    return NO;
}

- (BOOL)canStartAfterTask:(INAPITask*)other
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
    AFHTTPRequestOperation * op = [[[INAPIManager shared] AF] HTTPRequestOperationWithRequest:[self buildAPIRequest] success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self handleSuccess: operation withResponse: responseObject];
        [self setState: INAPITaskStateFinished];
        callback(self, YES);

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self handleFailure:operation withError:error];
		[self setPercentComplete: 0];

        NSURLRequest * request = [operation request];
        NSInteger code = [[operation response] statusCode];

        if ((code == 0) || (code >= 500) || (code == 305) || (code == 407) || (code == 408) || (code == 404) || (code == 405)) {
            // no connection, server error / unavailable, use proxy, proxy auth required, request timeout
            // We received an error that indicates future API calls will fail too.
            // Pause the operations queue and add this operation to it again.
            NSString * errorString = [NSString stringWithFormat:@"The server returned response code %d for %@ %@", (int)code, [request HTTPMethod], [request URL]];
            [_data setObject:errorString forKey:@"error"];
            NSLog(@"%@. Change %@ failed.",errorString, NSStringFromClass([self class]));

            [self setState: INAPITaskStateServerUnreachable];
            callback(self, NO);
        } else {
            // For some reason, we reached inbox and it rejected this operation. To maintain the consistency
            // of our cache, roll back the operation and we DO NOT try to send it again.
            NSLog(@"The server rejected %@ %@. Response code %d. To maintain the cache consistency, the update is being rolled back.", [request HTTPMethod], [request URL], (int)code);
            [self setState: INAPITaskStateServerRejected];
            [self rollbackLocally];
            callback(self, YES);
        }
    }];
    
	[op setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
		[self setPercentComplete: (double)totalBytesWritten / (double)totalBytesExpectedToWrite];
	}];

	[self setPercentComplete: 0.01];
    [self setState: INAPITaskStateInProgress];
    [[[[INAPIManager shared] AF] operationQueue] addOperation: op];
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


