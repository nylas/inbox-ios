//
//  INAPIManager.m
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPIManager.h"
#import "INAPIOperation.h"
#import "INNamespace.h"
#import "INModelResponseSerializer.h"
#import "INDatabaseManager.h"
#import "FMResultSet+INModelQueries.h"

#if DEBUG
  #define API_URL		[NSURL URLWithString:@"http://localhost:5555/"]
#else
  #define API_URL		[NSURL URLWithString:@"http://localhost:5555/"]
#endif

#define OPERATIONS_FILE [@"~/Documents/operations.plist" stringByExpandingTildeInPath]
#define AUTH_TOKEN_KEY  @"inbox-auth-token"

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

        NSString * token = [[NSUserDefaults standardUserDefaults] objectForKey:AUTH_TOKEN_KEY];
        if (token) {
            // refresh the namespaces available to our token if we have one
            [self.requestSerializer setAuthorizationHeaderFieldWithUsername:token password:nil];
            [self fetchNamespaces: NULL];
        }
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveOperations) name:UIApplicationWillTerminateNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(operationFinished:) name:AFNetworkingOperationDidFinishNotification object:nil];
		[self loadOperations];
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
    if (!operation.responseSerializer)
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

- (BOOL)isSignedIn
{
    return ([[NSUserDefaults standardUserDefaults] objectForKey:AUTH_TOKEN_KEY] != nil);
}

- (void)signIn:(ErrorBlock)completionBlock
{
    NSString * authToken = @"whatevs";
    
	[[self requestSerializer] setAuthorizationHeaderFieldWithUsername:authToken password:@""];
    [self fetchNamespaces:^(NSArray *namespaces, NSError *error) {
        if (error) {
            [[self requestSerializer] clearAuthorizationHeader];
            completionBlock(error);
        } else {
            [[NSUserDefaults standardUserDefaults] setObject:authToken forKey:AUTH_TOKEN_KEY];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:INAuthenticationChangedNotification object:nil];
            completionBlock(nil);
        }
    }];
}

- (void)signOut
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: AUTH_TOKEN_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[self requestSerializer] clearAuthorizationHeader];
    [[INDatabaseManager shared] resetDatabase];
    _namespaces = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:INNamespacesChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:INAuthenticationChangedNotification object:nil];
}

- (void)fetchNamespaces:(AuthenticationBlock)completionBlock
{
    NSLog(@"Fetching Namespaces (/n/)");
    AFHTTPRequestOperation * operation = [self GET:@"/n/" parameters:nil success:^(AFHTTPRequestOperation *operation, id namespaces) {
        // broadcast a notification about this change
        _namespaces = namespaces;
        [[NSNotificationCenter defaultCenter] postNotificationName:INNamespacesChangedNotification object:nil];
        if (completionBlock)
            completionBlock(namespaces, nil);

	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (completionBlock)
			completionBlock(nil, error);
	}];
    
    INModelResponseSerializer * serializer = [[INModelResponseSerializer alloc] initWithModelClass: [INNamespace class]];
    [operation setResponseSerializer: serializer];
}

- (NSArray*)namespaces
{
	if (!_namespaces) {
        [[INDatabaseManager shared] selectModelsOfClassSync:[INNamespace class] withQuery:@"SELECT * FROM INNamespace" andParameters:nil andCallback:^(NSArray *objects) {
            _namespaces = objects;
        }];
    }
    
    if ([_namespaces count] == 0)
        return nil;
    
	return _namespaces;
}

- (NSArray*)namespaceEmailAddresses
{
    return [[self namespaces] valueForKey:@"emailAddress"];
}

@end
