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

static NSString * INTaskProgressNotification = @"INTaskProgressNotification";

typedef enum : NSUInteger {
    INAPITaskStateWaiting,
    INAPITaskStateInProgress,
    INAPITaskStateFinished,
    INAPITaskStateCancelled,
    INAPITaskStateServerUnreachable,
    INAPITaskStateServerRejected
} INAPITaskState;


typedef void (^ CallbackBlock)(INAPITask * change, BOOL finished);

@interface INAPITask : NSObject <NSCoding>

@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) INModelObject * model;
@property (nonatomic, strong) NSMutableDictionary * data;
@property (nonatomic, assign) INAPITaskState state;
@property (nonatomic, assign) float percentComplete;

+ (instancetype)operationForModel:(INModelObject *)model;

- (id)initWithModel:(INModelObject*)model;
- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (BOOL)canCancelPendingTask:(INAPITask*)other;
- (BOOL)canStartAfterTask:(INAPITask*)other;
- (NSArray*)dependenciesIn:(NSArray*)others;

- (BOOL)inProgress;
- (NSString*)error;

- (void)applyLocally;
- (void)applyRemotelyWithCallback:(CallbackBlock)callback;
- (void)rollbackLocally;

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject;

@end
