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

@class INModelChange;
@class INModelObject;

typedef void (^ ResultsBlock)(NSArray * objects);
typedef void (^ ModelBlock)(INModelObject * object);
typedef void (^ LongBlock)(long count);
typedef void (^ AuthenticationBlock)(NSArray * namespaces, NSError * error);
typedef void (^ ErrorBlock)(NSError * error);
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
    NSMutableArray * _changeQueue;
    int _changesInProgress;
}

@property (nonatomic, assign) BOOL changeQueueSuspended;

+ (INAPIManager *)shared;

/**
 Queue the API operation provided. API operations are persisted to disk until they are
 completed and automatically restarted after network reachability changes occur. 

 @param operation The INAPIOperation to be performed.
*/
- (void)queueChange:(INModelChange *)change;

- (void)setChangeQueueSuspended:(BOOL)suspended;


#pragma Authentication

- (BOOL)isSignedIn;

- (void)signIn:(ErrorBlock)completionBlock;

- (void)signOut;


- (void)fetchNamespaces:(AuthenticationBlock)completionBlock;

/**
 @return The currently authenticated Inbox namespaces.
*/
- (NSArray*)namespaces;

/**
 @return The email addresses of the currently authenticated namespaces.
*/
- (NSArray*)namespaceEmailAddresses;

@end
