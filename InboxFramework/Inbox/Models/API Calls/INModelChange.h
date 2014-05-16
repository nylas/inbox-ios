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
{
    NSMutableArray * _dependencies;
}

@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) INModelObject * model;
@property (nonatomic, strong) NSMutableDictionary * data;
@property (nonatomic, assign) BOOL inProgress;

+ (instancetype)operationForModel:(INModelObject *)model;

- (id)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;

- (void)startWithCallback:(CallbackBlock)callback;

- (BOOL)dependentOnChangesIn:(NSArray*)others;
- (void)addDependency:(INModelChange*)otherChange;

- (void)applyLocally;
- (void)rollbackLocally;

@end

@interface INAPISaveOperation : INModelChange

@end

@interface INAPISaveDraftOperation : INModelChange

@end

@interface INAPIAddRemoveTagsOperation : INModelChange

- (NSMutableArray *)tagIDsToAdd;
- (NSMutableArray *)tagIDsToRemove;

@end