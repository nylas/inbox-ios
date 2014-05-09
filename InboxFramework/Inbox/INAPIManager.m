//
//  INAPIManager.m
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPIManager.h"
#import "INAPIOperation.h"
#import "INAccount.h"

#if DEBUG
  #define API_URL		[NSURL URLWithString:@"http://localhost:5555/"]
#else
  #define API_URL		[NSURL URLWithString:@"http://localhost:5555/"]
#endif

#define OPERATIONS_FILE [@"~/Documents/operations.plist" stringByExpandingTildeInPath]

__attribute__((constructor))
static void initialize_INAPIManager() {
    [INAPIManager shared];
}

@implementation INAPIManager

+ (INAPIManager *)shared
{
	static INAPIManager * sharedManager = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedManager = [[INAPIManager alloc] init];
	});
	return sharedManager;
}

- (id)init
{
	self = [super initWithBaseURL: API_URL];
	if (self) {
        [[self operationQueue] setMaxConcurrentOperationCount: 1]; // for testing
		[self setResponseSerializer:[AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingAllowFragments]];
		[self setRequestSerializer:[AFJSONRequestSerializer serializerWithWritingOptions:NSJSONWritingPrettyPrinted]];
		[self.requestSerializer setCachePolicy: NSURLRequestReloadRevalidatingCacheData];
		
		INAccount * account = [self account];
		dispatch_async(dispatch_get_main_queue(), ^{
			[account reload: NULL];
		});
		
		[self.requestSerializer setAuthorizationHeaderFieldWithUsername:account.authToken password:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveOperations) name:UIApplicationWillTerminateNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(operationFinished:) name:AFNetworkingOperationDidFinishNotification object:nil];
		[self loadOperations];
		
		[[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

		typeof(self) __weak __self = self;
		self.reachabilityManager = [AFNetworkReachabilityManager managerForDomain: [API_URL host]];
		[self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
			BOOL hasConnection = (status == AFNetworkReachabilityStatusReachableViaWiFi) || (status == AFNetworkReachabilityStatusReachableViaWWAN);
			BOOL hasSuspended = [__self.operationQueue isSuspended];

			if (hasConnection && hasSuspended)
				[__self setOperationsSuspended: NO];
			else if (!hasConnection && !hasSuspended)
				[__self setOperationsSuspended: YES];
		}];
		[self.reachabilityManager startMonitoring];
	}
	return self;
}

- (void)loadOperations
{
	NSArray * operations = [NSKeyedUnarchiver unarchiveObjectWithFile:OPERATIONS_FILE];

	// restore only INAPIOperations
	for (INAPIOperation * operation in operations)
		if ([operation isKindOfClass:[INAPIOperation class]])
			[self queueAPIOperation:operation];
	
	NSLog(@"Restored (%lu) pending operations from disk.", (unsigned long)self.operationQueue.operationCount);
}

- (void)saveOperations
{
	NSArray * operations = self.operationQueue.operations;
	if (![NSKeyedArchiver archiveRootObject:operations toFile:OPERATIONS_FILE])
		NSLog(@"Writing operations to disk failed? Path may be invalid.");
	else
		NSLog(@"Wrote (%lu) operations to disk.", (unsigned long)self.operationQueue.operationCount);
}

- (void)setOperationsSuspended:(BOOL)suspended
{
	[self.operationQueue setSuspended: suspended];
	if (suspended)
		NSLog(@"Suspended operation queue.");
	else
		NSLog(@"Resumed operation queue.");
}

- (void)queueAPIOperation:(INAPIOperation *)operation
{
	operation.responseSerializer = self.responseSerializer;
	operation.shouldUseCredentialStorage = self.shouldUseCredentialStorage;
	operation.credential = self.credential;
	operation.securityPolicy = self.securityPolicy;

	// does this operation "squash" any other operations? For example, a previous
	// "save" on the same message that hasn't been performed yet? If so, replace those.
	// This avoids the scenario where two PUTs to the same URL run concurrently and
	// produce an undefined end state.
	NSOperationQueue * queue = self.operationQueue;
	for (NSInteger ii = [queue operationCount] - 1; ii >= 0; ii--) {
		INAPIOperation * existing = [[queue operations] objectAtIndex:ii];
		if ([existing isCancelled] || [existing isExecuting] || [existing isFinished])
			continue;
		if (![existing isKindOfClass: [INAPIOperation class]])
			continue;
			
		if ([operation invalidatesPreviousQueuedOperation:existing]) {
			[operation setModelRollbackDictionary: [existing modelRollbackDictionary]];
			[existing cancel];
		}
	}

	[self.operationQueue addOperation:operation];
}

- (void)operationFinished:(NSNotification*)notif
{
	INAPIOperation * operation = [notif object];
	NSInteger code = [[operation response] statusCode];
	
	if (![operation isKindOfClass: [INAPIOperation class]])
		return;
		
	// success
	if ((code >= 200) && (code <= 204)) {
		[[NSNotificationCenter defaultCenter] postNotificationName:INAPIOperationCompleteNotification object:operation userInfo:@{@"success": @(YES)}];
	
	// no connection, server error / unavailable, use proxy, proxy auth required, request timeout
	} else if ((code == 0) || (code >= 500) || (code == 305) || (code == 407) || (code == 408)) {
		[[NSNotificationCenter defaultCenter] postNotificationName:INAPIOperationCompleteNotification object:operation userInfo:@{@"success": @(NO)}];

		// We received an error that indicates future API calls will fail too.
		// Pause the operations queue and add this operation to it again.
		[self setOperationsSuspended: YES];
		[self.operationQueue addOperation: [operation copy]];
		
	// unknown error
	} else {
		// For some reason, we reached inbox and it rejected this operation. To maintain the consistency
		// of our cache, roll back the operation.
		NSLog(@"The server rejected %@ %@. Response code %d. To maintain the cache consistency, the update is being rolled back.", [[operation request] HTTPMethod], [[operation request] URL], code);
		[(INAPIOperation*)operation rollback];
	}
}

#pragma Authentication

- (void)authenticate:(AuthenticationBlock)completionBlock
{
	// TODO: Insert auth to get user ID here
	NSString * userID = @"q1fuaeq3qe8vjtbu7hglrzi5";
	NSString * authToken = @"whatevs";
	
	NSString * userPath = [NSString stringWithFormat: @"/u/%@", userID];
	
	[[self requestSerializer] setAuthorizationHeaderFieldWithUsername:authToken password:@""];
	[self GET:userPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		INAccount * account = [[INAccount alloc] init];
		[account updateWithResourceDictionary: responseObject];
		[account setAuthToken: authToken];
		
		int __block __loading = 0;
		for (INNamespace * namespace in [account namespaces]) {
			__loading+=1;
			
			[namespace reload:^(NSError *error) {
				__loading -=1;
				if (__loading == 0) {
					// initialize all namespace objects before we announce an account change
					[self setAccount: account];
					
					if (completionBlock)
						completionBlock(account, nil);
				}
			}];
		}

	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (completionBlock)
			completionBlock(nil, error);
	}];
}

- (INAccount*)account
{
	if (_account)
		return _account;
	
	_account = (INAccount*)[[INDatabaseManager shared] selectModelOfClass: [INAccount class] withID: nil];
	return _account;
}

- (void)setAccount:(INAccount *)account
{
	_account = account;

	// destroy our local cache
	[[INDatabaseManager shared] resetDatabase];
	[[INDatabaseManager shared] persistModel: _account];

	// broadcast a notification about this change
    [[NSNotificationCenter defaultCenter] postNotificationName:INAccountChangedNotification object:nil];
}

@end
