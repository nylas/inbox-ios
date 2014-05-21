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

typedef void (^ CallbackBlock)(INModelChange * change, BOOL finished);

@interface INModelChange : NSObject <NSCoding>

@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) INModelObject * model;
@property (nonatomic, strong) NSMutableDictionary * data;
@property (nonatomic, assign) BOOL inProgress;

+ (instancetype)operationForModel:(INModelObject *)model;

- (id)initWithModel:(INModelObject*)model;
- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (BOOL)canCancelPendingChange:(INModelChange*)other;
- (BOOL)canStartAfterChange:(INModelChange*)other;
- (NSArray*)dependenciesIn:(NSArray*)others;

- (void)applyLocally;
- (void)applyRemotelyWithCallback:(CallbackBlock)callback;
- (void)rollbackLocally;

@end
