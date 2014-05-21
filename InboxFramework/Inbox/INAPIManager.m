//
//  INAPIManager.m
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPIManager.h"
#import "INModelChange.h"
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
        [[self operationQueue] setMaxConcurrentOperationCount: 5];
		[self setResponseSerializer:[AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingAllowFragments]];
		[self setRequestSerializer:[AFJSONRequestSerializer serializerWithWritingOptions:NSJSONWritingPrettyPrinted]];
		[self.requestSerializer setCachePolicy: NSURLRequestReloadRevalidatingCacheData];
		
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

        typeof(self) __weak __self = self;
		self.reachabilityManager = [AFNetworkReachabilityManager managerForDomain: [API_URL host]];
		[self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
			BOOL hasConnection = (status == AFNetworkReachabilityStatusReachableViaWiFi) || (status == AFNetworkReachabilityStatusReachableViaWWAN);
			BOOL hasSuspended = __self.changeQueueSuspended;
            
			if (hasConnection && hasSuspended)
				[__self setChangeQueueSuspended: NO];
			else if (!hasConnection && !hasSuspended)
				[__self setChangeQueueSuspended: YES];
		}];
		[self.reachabilityManager startMonitoring];

        NSString * token = [[NSUserDefaults standardUserDefaults] objectForKey:AUTH_TOKEN_KEY];
        if (token) {
            // refresh the namespaces available to our token if we have one
            [self.requestSerializer setAuthorizationHeaderFieldWithUsername:token password:nil];
            [self fetchNamespaces: NULL];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadChangeQueue];
        });
    }
	return self;
}

- (void)loadChangeQueue
{
    _changeQueue = [NSMutableArray array];
    [_changeQueue addObjectsFromArray: [NSKeyedUnarchiver unarchiveObjectWithFile:OPERATIONS_FILE]];
    
    NSArray * toStart = [_changeQueue copy];
	for (INModelChange * change in toStart)
        [self tryStartChange: change];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:INChangeQueueChangedNotification object:nil];
    [self describeChangeQueue];
}

- (void)saveChangeQueue
{
	if (![NSKeyedArchiver archiveRootObject:_changeQueue toFile:OPERATIONS_FILE])
		NSLog(@"Writing pending changes to disk failed? Path may be invalid.");
}

- (NSArray*)changeQueue
{
    return [_changeQueue copy];
}

- (void)setChangeQueueSuspended:(BOOL)suspended
{
    NSLog(@"Change processing is %@.", (suspended ? @"off" : @"on"));

    _changeQueueSuspended = suspended;
    [[NSNotificationCenter defaultCenter] postNotificationName:INChangeQueueChangedNotification object:nil];

	if (!suspended) {
        for (INModelChange * change in _changeQueue)
            [self tryStartChange: change];
    }
}

- (BOOL)queueChange:(INModelChange *)change
{
    NSAssert([NSThread isMainThread], @"Sorry, INAPIManager's change queue is not threadsafe. Please call this method on the main thread.");
    
    for (int ii = [_changeQueue count] - 1; ii >= 0; ii -- ) {
        INModelChange * a = [_changeQueue objectAtIndex: ii];

        // Can the change we're currently queuing obviate the need for A? If it
        // can, there's no need to make the API call for A.
        // Example: DeleteDraft cancels pending SaveDraft or SendDraft
        if (![a inProgress] && [change canCancelPendingChange: a]) {
            NSLog(@"%@ CANCELLING CHANGE %@", NSStringFromClass([change class]), NSStringFromClass([a class]));
            [_changeQueue removeObjectAtIndex: ii];
        }
        
        // Can the change we're currently queueing happen after A? We can't cancel
        // A since it's already started.
        // Example: DeleteDraft can't be queued if SendDraft has started.
        if ([a inProgress] && ![change canStartAfterChange: a]) {
            NSLog(@"%@ CANNOT BE QUEUED AFTER %@", NSStringFromClass([change class]), NSStringFromClass([a class]));
            return NO;
        }
    }

    [_changeQueue addObject: change];

    if ([[change dependenciesIn: _changeQueue] count] == 0) {
        [change applyLocally];
        [self tryStartChange: change];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:INChangeQueueChangedNotification object:nil];
    [self describeChangeQueue];
    [self saveChangeQueue];

    return YES;
}

- (void)describeChangeQueue
{
	NSMutableString * description = [NSMutableString string];
	[description appendFormat:@"\r------- Change Queue (%d) Suspended: %d -------", _changeQueue.count, _changeQueueSuspended];

	for (INModelChange * change in _changeQueue) {
		NSString * dependencyIDs = [[[change dependenciesIn: _changeQueue] valueForKey: @"description"] componentsJoinedByString:@"\r"];
		[description appendFormat:@"\r%@\r     - in progress: %d \r     - dependencies: %@", [change description], [change inProgress], dependencyIDs];
	}
    [description appendFormat:@"\r-------- ------ ------ ------ ------ ---------"];

	NSLog(@"%@", description);
}
    
- (BOOL)tryStartChange:(INModelChange *)change
{
    if (_changesInProgress > 5)
        return NO;
    
    if (_changeQueueSuspended)
        return NO;
    
    if ([[change dependenciesIn: _changeQueue] count] > 0)
        return NO;

    if ([change inProgress])
        return NO;
    
    _changesInProgress += 1;
    [change applyRemotelyWithCallback: ^(INModelChange * change, BOOL finished) {
        _changesInProgress -= 1;
        
        if (!finished) {
            [self setChangeQueueSuspended: YES];

        } else {
            [_changeQueue removeObject: change];
            for (INModelChange * change in _changeQueue)
                if ([self tryStartChange: change])
                    break;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:INChangeQueueChangedNotification object:nil];
        [self describeChangeQueue];
        [self saveChangeQueue];
    }];
    return YES;
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
    
	[_changeQueue removeAllObjects];
    [[self requestSerializer] clearAuthorizationHeader];
    [[INDatabaseManager shared] resetDatabase];
    _namespaces = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:INChangeQueueChangedNotification object:nil];
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
