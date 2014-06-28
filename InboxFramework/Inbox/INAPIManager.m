//
//  INAPIManager.m
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPIManager.h"
#import "INAPITask.h"
#import "INSyncEngine.h"
#import "INNamespace.h"
#import "INModelResponseSerializer.h"
#import "INDatabaseManager.h"
#import "FMResultSet+INModelQueries.h"
#import "INPDKeychainBindings.h"
#import "NSError+InboxErrors.h"

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
    NSString * api = [[NSBundle mainBundle] infoDictionary][INAPIPathInfoDictionaryKey];
    if (!api)
        api = @"http://api.inboxapp.com/";
    
	self = [super initWithBaseURL: [NSURL URLWithString: api]];
	if (self) {
        [[self operationQueue] setMaxConcurrentOperationCount: 5];
		[self setResponseSerializer:[AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingAllowFragments]];
		[self setRequestSerializer:[AFJSONRequestSerializer serializerWithWritingOptions:NSJSONWritingPrettyPrinted]];

        AFSecurityPolicy * policy = [AFSecurityPolicy defaultPolicy];
        [policy setAllowInvalidCertificates: YES];
        [self setSecurityPolicy: policy];
        [self.requestSerializer setCachePolicy: NSURLRequestReloadRevalidatingCacheData];
    
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

		// Register for changes to application state
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppBroughtToForeground) name:UIApplicationDidBecomeActiveNotification object:nil];

		// Start listening for reachability changes
        typeof(self) __weak __self = self;
		self.reachabilityManager = [AFNetworkReachabilityManager managerForDomain: [self.baseURL host]];
		[self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
			BOOL hasConnection = (status == AFNetworkReachabilityStatusReachableViaWiFi) || (status == AFNetworkReachabilityStatusReachableViaWWAN);
			BOOL hasSuspended = __self.taskQueueSuspended;
            
			if (hasConnection && hasSuspended)
				[__self setTaskQueueSuspended: NO];
			else if (!hasConnection && !hasSuspended)
				[__self setTaskQueueSuspended: YES];
		}];
		[self.reachabilityManager startMonitoring];


		// Make sure the application has an Inbox App ID in it's info.plist
		NSDictionary * info = [[NSBundle mainBundle] infoDictionary];
		_appID = [info objectForKey: INAppIDInfoDictionaryKey];
		NSAssert(_appID, @"Your application's Info.plist should include, INAppID, your Inbox App ID. If you don't have an app ID, grab one from developer.inboxapp.com");

		// Reload our API token and refresh the namespaces list
        NSString * token = [[INPDKeychainBindings sharedKeychainBindings] objectForKey:INKeychainAPITokenKey];
		[self.requestSerializer setAuthorizationHeaderFieldWithUsername:token password:nil];
        if (token) {
            [self fetchNamespaces: NULL];
        }
		
		// Restart paused tasks (sending mail, etc.)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadTasks];
        });
    }
	return self;
}

- (void)loadTasks
{
    _taskQueue = [NSMutableArray array];
	@try {
		[_taskQueue addObjectsFromArray: [NSKeyedUnarchiver unarchiveObjectWithFile:OPERATIONS_FILE]];
	}
	@catch (NSException *exception) {
		NSLog(@"Unable to unserialize tasks: %@", [exception description]);
		[[NSFileManager defaultManager] removeItemAtPath:OPERATIONS_FILE error:NULL];
	}
    
    NSArray * toStart = [_taskQueue copy];
	for (INAPITask * task in toStart)
        [self tryStartTask: task];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:INTaskQueueChangedNotification object:nil];
    [self describeTasks];
}

- (void)saveTasks
{
	if (![NSKeyedArchiver archiveRootObject:_taskQueue toFile:OPERATIONS_FILE])
		NSLog(@"Writing pending changes to disk failed? Path may be invalid.");
}

- (NSArray*)taskQueue
{
    return [_taskQueue copy];
}

- (void)setTaskQueueSuspended:(BOOL)suspended
{
    NSLog(@"Change processing is %@.", (suspended ? @"off" : @"on"));

    _taskQueueSuspended = suspended;
    [[NSNotificationCenter defaultCenter] postNotificationName:INTaskQueueChangedNotification object:nil];

	if (!suspended) {
        for (INAPITask * change in _taskQueue)
            [self tryStartTask: change];
    }
}

- (BOOL)queueTask:(INAPITask *)change
{
    NSAssert([NSThread isMainThread], @"Sorry, INAPIManager's change queue is not threadsafe. Please call this method on the main thread.");
    
    for (NSInteger ii = [_taskQueue count] - 1; ii >= 0; ii -- ) {
        INAPITask * a = [_taskQueue objectAtIndex: ii];

        // Can the change we're currently queuing obviate the need for A? If it
        // can, there's no need to make the API call for A.
        // Example: DeleteDraft cancels pending SaveDraft or SendDraft
        if (![a inProgress] && [change canCancelPendingTask: a]) {
            NSLog(@"%@ CANCELLING CHANGE %@", NSStringFromClass([change class]), NSStringFromClass([a class]));
            [a setState: INAPITaskStateCancelled];
            [_taskQueue removeObjectAtIndex: ii];
        }
        
        // Can the change we're currently queueing happen after A? We can't cancel
        // A since it's already started.
        // Example: DeleteDraft can't be queued if SendDraft has started.
        if ([a inProgress] && ![change canStartAfterTask: a]) {
            NSLog(@"%@ CANNOT BE QUEUED AFTER %@", NSStringFromClass([change class]), NSStringFromClass([a class]));
            return NO;
        }
    }

    // Local effects always take effect immediately
    [change applyLocally];

    // Queue the task, and try to start it after a short delay. The delay is purely for
    // asthethic purposes. Things almost always look better when they appear to take a
    // short amount of time, and lots of animations look like shit when they happen too
    // fast. This ensures that, for example, the "draft synced" passive reload doesn't
    // happen while the "draft saved!" animation is still playing, which results in the
    // animation being disrupted. Unless there's really a good reason to make developers
    // worry about stuff like that themselves, let's keep this here.
    [_taskQueue addObject: change];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self tryStartTask: change];
    });

    [[NSNotificationCenter defaultCenter] postNotificationName:INTaskQueueChangedNotification object:nil];
    [self describeTasks];
    [self saveTasks];

    return YES;
}

- (void)describeTasks
{
	NSMutableString * description = [NSMutableString string];
	[description appendFormat:@"\r---------- Tasks (%lu) Suspended: %d -----------", (unsigned long)_taskQueue.count, _taskQueueSuspended];

	for (INAPITask * change in _taskQueue) {
		NSString * dependencyIDs = [[[change dependenciesIn: _taskQueue] valueForKey: @"description"] componentsJoinedByString:@"\r          "];
        NSString * stateString = @[@"waiting", @"in progress", @"finished", @"server-unreachable", @"server-rejected"][[change state]];
		[description appendFormat:@"\r%@\r     - state: %@ \r     - error: %@ \r     - dependencies: %@", [change description], stateString, [change error], dependencyIDs];
	}
    [description appendFormat:@"\r-------- ------ ------ ------ ------ ---------"];

	NSLog(@"%@", description);
}

- (void)retryTasks
{
    for (INAPITask * task in _taskQueue) {
        if ([task state] == INAPITaskStateServerUnreachable)
            [task setState: INAPITaskStateWaiting];
        [self tryStartTask: task];
    }
}

- (BOOL)tryStartTask:(INAPITask *)change
{
    if ([change state] != INAPITaskStateWaiting)
        return NO;
    
    if (_changesInProgress > 5)
        return NO;
    
    if (_taskQueueSuspended)
        return NO;
    
    if ([[change dependenciesIn: _taskQueue] count] > 0)
        return NO;

    _changesInProgress += 1;
    [change applyRemotelyWithCallback: ^(INAPITask * change, BOOL finished) {
        _changesInProgress -= 1;
        
        if (finished) {
            [_taskQueue removeObject: change];
            for (INAPITask * change in _taskQueue)
                if ([self tryStartTask: change])
                    break;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:INTaskQueueChangedNotification object:nil];
        [self describeTasks];
        [self saveTasks];
    }];
    return YES;
}


#pragma Authentication

- (BOOL)isAuthenticated
{
    return ([[INPDKeychainBindings sharedKeychainBindings] objectForKey:INKeychainAPITokenKey] != nil);
}

- (void)authenticateWithEmail:(NSString*)address andCompletionBlock:(ErrorBlock)completionBlock;
{
	if (_authenticationCompletionBlock && (_authenticationCompletionBlock != completionBlock))
		NSLog(@"A call to authenticateWithEmail: is replacing an authentication completion block that has not yet been fired. The old authentication block will never be called!");
	_authenticationCompletionBlock = completionBlock;
	
	// make sure the application is registered for it's application url scheme
	BOOL found = NO;
	_appURLScheme = [[NSString stringWithFormat:@"in-%@", _appID] lowercaseString];
	for (NSDictionary * urlType in [[NSBundle mainBundle] infoDictionary][@"CFBundleURLTypes"]) {
		for (NSString * scheme in urlType[@"CFBundleURLSchemes"]) {
			if ([[scheme lowercaseString] isEqualToString: _appURLScheme])
				found = YES;
		}
	}
	NSAssert(found, @"Your application's Info.plist should register your app for the '%@' URL scheme to handle Inbox authentication correctly.", _appURLScheme);

	// make sure we can reach the server before we try to open the auth page in safari
	if ([[self reachabilityManager] networkReachabilityStatus] == AFNetworkReachabilityStatusNotReachable) {
		NSError * err = [NSError inboxErrorWithDescription: @"Sorry, you need to be connected to the internet to connect your account."];
		[self handleAuthenticationCompleted: NO withError: err];
		return;
	}
	
	// try to visit the auth URL in Safari
    NSString * uri = [NSString stringWithFormat: @"%@://app/auth-response", _appURLScheme];
	NSString * authPage = [NSString stringWithFormat: @"%@oauth/authorize?client_id=%@&response_type=token&login_hint=%@&redirect_uri=%@", [self.baseURL absoluteString], _appID, address, uri];

	if ([[UIApplication sharedApplication] openURL: [NSURL URLWithString:authPage]]) {
		_authenticationWaitingForInboundURL = YES;

	} else {
		NSError * err = [NSError inboxErrorWithDescription: @"Sorry, we weren't able to switch to Safari to open the authentication URL."];
		[self handleAuthenticationCompleted: NO withError: err];
	}
}

- (void)authenticateWithAuthToken:(NSString*)authToken andCompletionBlock:(ErrorBlock)completionBlock
{
	if (_authenticationCompletionBlock && (_authenticationCompletionBlock != completionBlock))
		NSLog(@"A call to authenticateWithAuthToken: is replacing an authentication completion block that has not yet been fired. The old authentication block will never be called!");
	_authenticationCompletionBlock = completionBlock;
	
	[[self requestSerializer] setAuthorizationHeaderFieldWithUsername:authToken password:@""];
    [self fetchNamespaces:^(BOOL success, NSError * error) {
        if (success) {
            [[INPDKeychainBindings sharedKeychainBindings] setObject:authToken forKey:INKeychainAPITokenKey];
            [[NSNotificationCenter defaultCenter] postNotificationName:INAuthenticationChangedNotification object:nil];
		} else {
            [[self requestSerializer] clearAuthorizationHeader];
        }

		[self handleAuthenticationCompleted: success withError: error];
    }];
}

- (void)unauthenticate
{
	[_taskQueue removeAllObjects];
    [_syncEngine resetSyncState];
    [[INPDKeychainBindings sharedKeychainBindings] removeObjectForKey: INKeychainAPITokenKey];
    [[self requestSerializer] clearAuthorizationHeader];
    [[INDatabaseManager shared] resetDatabase];
    _namespaces = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:INTaskQueueChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:INNamespacesChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:INAuthenticationChangedNotification object:nil];
}

- (BOOL)handleURL:(NSURL*)url
{
	if (![[[url scheme] lowercaseString] isEqualToString: _appURLScheme])
		return NO;
		
	if ([[url path] isEqualToString: @"/auth-response"]) {
		_authenticationWaitingForInboundURL = NO;

		NSMutableDictionary * responseComponents = [NSMutableDictionary dictionary];
		for (NSString * arg in [[url query] componentsSeparatedByString:@"&"]) {
			NSArray * kv = [arg componentsSeparatedByString: @"="];
			if ([kv count] < 2) continue;
			[responseComponents setObject:kv[1] forKey:kv[0]];
		}

		if (responseComponents[@"access_token"]) {
			// we got an auth token! Continue authentication with this token
			[self authenticateWithAuthToken:responseComponents[@"access_token"] andCompletionBlock: _authenticationCompletionBlock];
			
		} else if (responseComponents[@"code"]) {
			// we got a code that we need to exchange for an auth token. We can't do this locally
			// because the client secret should never be in the application. Just report an error
			NSError * err = [NSError inboxErrorWithDescription: @"Inbox received an auth code instead of an auth token and can't exchange the code for a valid token."];
			[self handleAuthenticationCompleted: NO withError: err];
		}
	}

	return YES;
}

- (void)handleAppBroughtToForeground
{
	// If the app is brought to the foreground after being backgrounded during an authentication
	// request, and we _don't_ receive a call to handleURL: after 0.5 seconds, we should assume
	// that they're trying to get out of the auth process and end it.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (_authenticationWaitingForInboundURL) {
			[self handleAuthenticationCompleted: NO withError:nil];
		}
	});
}

- (void)handleAuthenticationCompleted:(BOOL)success withError:(NSError*)error
{
	_authenticationWaitingForInboundURL = NO;
	
	if (_authenticationCompletionBlock) {
		_authenticationCompletionBlock(success, error);
		_authenticationCompletionBlock = nil;
		
	} else {
		if (error) {
			[[[UIAlertView alloc] initWithTitle:@"Login Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
		}
	}
}

- (void)fetchNamespaces:(ErrorBlock)completionBlock
{
    NSLog(@"Fetching Namespaces (/n/)");
    AFHTTPRequestOperation * operation = [self GET:@"/n/" parameters:nil success:^(AFHTTPRequestOperation *operation, id namespaces) {
        // broadcast a notification about this change
        _namespaces = namespaces;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:INNamespacesChangedNotification object:nil];

        if ([namespaces count] == 0) {
            if (completionBlock)
                completionBlock(NO, [NSError inboxErrorWithDescription: @"The token was valid, but returned no namespaces."]);
        } else {
            if (completionBlock)
                completionBlock(YES, nil);
        }
        
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		if (completionBlock)
			completionBlock(NO, error);
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
