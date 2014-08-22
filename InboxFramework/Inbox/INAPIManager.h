//
//  INAPIManager.h
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFHTTPRequestOperationManager;

static NSString * INNamespacesChangedNotification = @"INNamespacesChangedNotification";
static NSString * INAuthenticationChangedNotification = @"INAuthenticationChangedNotification";
static NSString * INTaskQueueChangedNotification = @"INTaskQueueChangedNotification";

static NSString * INAppIDInfoDictionaryKey = @"INAppID";
static NSString * INAPIPathInfoDictionaryKey = @"INAPIPath";
static NSString * INKeychainAPITokenKey = @"inbox-api-token";

@class INAPITask;
@class INModelObject;
@class AFHTTPRequestSerializer;
@class AFHTTPResponseSerializer;
@protocol INSyncEngine;

typedef void (^ ResultsBlock)(NSArray * objects);
typedef void (^ ResultBlock)(id result, NSError * error);
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
@interface INAPIManager : NSObject
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
@property (nonatomic, strong) AFHTTPRequestOperationManager * AF;
@property (nonatomic, strong) NSObject<INSyncEngine> * syncEngine;


+ (INAPIManager *)shared;

/**
Returns an immutable copy of the task queue so it can be inspected or displayed.

@return a copy of the task queue
*/
- (NSArray*)taskQueue;

/**
 Queue the API operation provided. API operations are persisted to disk until they are
 completed and automatically restarted after network reachability changes occur. 

 @param change The INAPIOperation to be performed.
 @return YES, if the change was successfully queued. NO if the change could not be
 queued because of another change that is already in progress and would conflict.
 */
- (BOOL)queueTask:(INAPITask *)change;

/**
Retry all the tasks which have failed with status INAPITaskStateServerUnreachable, 
indicating that they can be retryed and may succeed.
*/
- (void)retryTasks;

/**
Suspend or resume the task queue. This method is called automatically when reachability
status changes, but it may be useful to resume the queue menually in response to user
action.

@param suspended YES to suspend the processing of queued API tasks, NO to resume
processing tasks immediately. Note that the queue will be suspended again if a queued
task fails.
*/
- (void)setTaskQueueSuspended:(BOOL)suspended;


#pragma Convenience Serializers

- (AFHTTPResponseSerializer*)responseSerializerForClass:(Class)klass;


#pragma Authentication

- (BOOL)isAuthenticated;

/**
 Set the current Auth Token and fetch available namespaces. Calls the completionBlock
 after the namespaces request returns.
*/
- (void)authenticateWithAuthToken:(NSString*)authToken andCompletionBlock:(ErrorBlock)completionBlock;

/**
 Bounces out to Safari and prompts the user to enter their email address. Then directs the
 user to the appropriate sign-in page for their email address. Inbox triggers a redirect back
 to the app with the auth token, and the completionBlock is fired after the token is saved and
 namespaces for the token are fetched.
*/
- (void)authenticateWithCompletionBlock:(ErrorBlock)completionBlock;

/**
 Bounces out to Safari and directs the user to the appropriate sign-in page for their email address.
 Inbox triggers a redirect back to the app with the auth token, and the completionBlock is fired
 after the token is saved and namespaces for the token are fetched.
 */
 - (void)authenticateWithEmail:(NSString*)address andCompletionBlock:(ErrorBlock)completionBlock;

/**
 Clears the cached authentication token and signs out.
 */
- (void)unauthenticate;

/**
 handleURL: should be called from your appication's app delegate in response to
 application:openURL:sourceApplication:annotation:. Inbox uses a special URL scheme
 to complete authentication and allow for deep linking.
 
 @param url The URL that your application was asked to open

 @return YES, if url was an Inbox URL and was handled by the INAPIManager, NO if your
 application should futher handle the URL and process it on it's own.
*/
- (BOOL)handleURL:(NSURL*)url;

/**
Fetch the namespaces available to the app with the current auth token.

@param completionBlock If the completion block parameters indicate that the request was
successful, calls to -namespaces will return the fetched namespaces.
*/
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
