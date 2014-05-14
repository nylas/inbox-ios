//
//  INNamespace.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelProvider.h"

@class INThreadProvider;

@interface INNamespace : INModelObject

@property (nonatomic, strong) NSString * emailAddress;
@property (nonatomic, strong) NSString * provider;
@property (nonatomic, strong) NSString * status;
@property (nonatomic, strong) NSArray * scope;
@property (nonatomic, strong) NSDate * lastSync;

- (INModelProvider *)newContactProvider;
- (INThreadProvider *)newThreadProvider;
- (INModelProvider *)newTagProvider;

@end
