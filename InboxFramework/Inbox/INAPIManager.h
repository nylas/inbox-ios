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

static NSString * INAccountChangedNotification = @"INAccountChangedNotification";

@class INAPIOperation;
@class INModelObject;
@class INAccount;

typedef void (^ ResultsBlock)(NSArray * objects);
typedef void (^ ModelBlock)(INModelObject * object);
typedef void (^ AuthenticationBlock)(INAccount * account, NSError * error);
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
	INAccount * _account;
}

+ (INAPIManager *)shared;

/**
 Queue the API operation provided. API operations are persisted to disk until they are
 completed and automatically restarted after network reachability changes occur. 

 @param operation The INAPIOperation to be performed.
*/
- (void)queueAPIOperation:(INAPIOperation *)operation;

#pragma Authentication

- (void)authenticate:(AuthenticationBlock)completionBlock;

/**
 @return The currently authenticated Inbox account, if one exists.
*/
- (INAccount*)account;

@end
