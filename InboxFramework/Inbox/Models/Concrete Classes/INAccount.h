//
//  INUser.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelProvider.h"
#import "INNamespace.h"

@interface INAccount : INModelObject

@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSArray * namespaceIDs;
@property (nonatomic, strong) NSString * authToken;

- (NSArray*)namespaces;
- (NSArray*)ownEmailAddresses;

@end
