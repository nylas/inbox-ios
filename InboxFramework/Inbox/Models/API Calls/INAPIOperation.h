//
//  INAPICall.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INModelObject.h"

@class INMessage;

static NSString * INAPIOperationCompleteNotification = @"INAPIOperationCompleteNotification";

@interface INAPIOperation : AFHTTPRequestOperation <NSCoding>

@property (nonatomic, strong) INModelObject * model;
@property (nonatomic, strong) NSDictionary * modelRollbackDictionary;

+ (INAPIOperation *)operationWithMethod:(NSString *)method forModel:(INModelObject *)model;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

/**
 Checks to see if this operation would overwrite the data PUT by another opration.
 For example, a previous "save" on the same model object that hasn't been performed yet.
 Cancelling those operations helps avoid the scenario where two PUTs to the same URL run
 concurrently and produce an undefined end state.
 
 @param other Another AFHTTPRequestOperation that has not yet been started.
 @return YES, if 'other' would be overwritten by this change and can be safely cancelled.
*/
- (BOOL)invalidatesPreviousQueuedOperation:(AFHTTPRequestOperation *)other;

/**
 Revert the impacted model to it's previous state using the rollback dictionary
 that was stored when the operation was created.
*/
- (void)rollback;

@end

@interface INAPISaveDraftOperation : INAPIOperation

@end

@interface INAPIAddRemoveTagsOperation : INAPIOperation

@end