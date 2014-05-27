//
//  INAPIManager.h
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

static NSString * INNamespacesChangedNotification = @"INNamespacesChangedNotification";
static NSString * INAuthenticationChangedNotification = @"INAuthenticationChangedNotification";
static NSString * INTaskQueueChangedNotification = @"INTaskQueueChangedNotification";

static NSString * INAppIDInfoDictionaryKey = @"INAppID";
static NSString * INKeychainAPITokenKey = @"inbox-api-token";

@class INAPITask;
@class INModelObject;
@protocol INSyncEngine;

typedef void (^ ResultsBlock)(NSArray * objects);
typedef void (^ ModelBlock)(INModelObject * object);
typedef void (^ LongBlock)(long count);
typedef void (^ ErrorBlock)(BOOL success, NSError * error);
typedef void (^ VoidBlock)();

/**
 The INAPIManager provides an interface for making authenticated Inbox API requests
 and handling user authentication flow.
 
 You can make Inbox API requests directly using the underlying AFHTTPRequestOperationManager
 methods -GET:, -POST:, -PUT:, etc. However, for user actions that trigger model changes,
 such as sending a message, flagging a thread, etc., you should create and queue 
 INAPIOperations. In most cases, there are higher-level APIs for creating these operations,
 such as calling -markAsRead on an INThread, and you don't need to use the INAPIManager directly.
 The INAPIManager queues these operations and ensures that they are eventually performed
 on the server, even though an internet connection might not be immediately available.
*/
@interface INAPIManager : AFHTTPRequestOperationManager
{
	NSArray * _namespaces;
	NSString * _appID;
	NSString * _appURLScheme;
    NSMutableArray * _taskQueue;
    int _changesInProgress;
	
	BOOL _authenticationWaitingForInboundURL;
	ErrorBlock _authenticationCompletionBlock;
}

@property (nonatomic, assign) BOOL taskQueueSuspended;

@property (nonatomic, strong) NSObject<INSyncEngine> * syncEngine;


+ (INAPIManager *)shared;

- (NSArray*)taskQueue;
/**
 Queue the API operation provided. API operations are persisted to disk until they are
 completed and automatically restarted after network reachability changes occur. 

 @param operation The INAPIOperation to be performed.
 @return YES, if the change was successfully queued. NO if the change could not be
 queued because of another change that is already in progress and would conflict.
 */
- (BOOL)queueTask:(INAPITask *)change;

- (void)retryTasks;

- (void)setTaskQueueSuspended:(BOOL)suspended;


#pragma Authentication

- (BOOL)isAuthenticated;

- (void)authenticateWithEmail:(NSString*)address andCompletionBlock:(ErrorBlock)completionBlock;

- (void)authenticateWithAuthToken:(NSString*)authToken andCompletionBlock:(ErrorBlock)completionBlock;

- (void)unauthenticate;

- (BOOL)handleURL:(NSURL*)url;

- (void)fetchNamespaces:(ErrorBlock)completionBlock;

/**
 @return The currently authenticated Inbox namespaces.
*/
- (NSArray*)namespaces;

/**
 @return The email addresses of the currently authenticated namespaces.
*/
- (NSArray*)namespaceEmailAddresses;

@end
