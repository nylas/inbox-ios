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

	for (INModelChange * change in _changeQueue)
        [self tryStartChange: change];
	
    [self describeChangeQueue];
}

- (void)saveChangeQueue
{
	if (![NSKeyedArchiver archiveRootObject:_changeQueue toFile:OPERATIONS_FILE])
		NSLog(@"Writing pending changes to disk failed? Path may be invalid.");
}

- (void)setChangeQueueSuspended:(BOOL)suspended
{
    NSLog(@"Change processing is %@.", (suspended ? @"off" : @"on"));

    _changeQueueSuspended = suspended;
	if (!suspended) {
        for (INModelChange * change in _changeQueue)
            [self tryStartChange: change];
    }
}

- (void)queueChange:(INModelChange *)change
{
    [_changeQueue addObject: change];

    if (![change dependentOnChangesIn: _changeQueue]) {
        [change applyLocally];
        [self tryStartChange: change];
    }

    [self describeChangeQueue];
    [self saveChangeQueue];
}

- (void)describeChangeQueue
{
    NSLog(@" ------ Change Queue (%d) ------", _changeQueue.count);
    NSLog(@"%@", [_changeQueue description]);
}
    
- (BOOL)tryStartChange:(INModelChange *)change
{
    if (_changesInProgress > 5)
        return NO;
    
    if (_changeQueueSuspended)
        return NO;
    
    if ([change dependentOnChangesIn: _changeQueue])
        return NO;

    if ([change inProgress])
        return NO;
    
    _changesInProgress += 1;
    [change startWithCallback: ^(INModelChange * change, BOOL finished) {
        _changesInProgress -= 1;
        
        if (!finished) {
            [self setChangeQueueSuspended: YES];

        } else {
            [_changeQueue removeObject: change];
            for (INModelChange * change in _changeQueue)
                if ([self tryStartChange: change])
                    break;
        }

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
