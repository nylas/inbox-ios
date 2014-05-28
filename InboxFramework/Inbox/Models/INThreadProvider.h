//
//  INThreadProvider.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelProvider.h"
#import "INNamespace.h"

@interface INThreadProvider : INModelProvider

- (id)initWithNamespaceID:(NSString *)namespaceID;

- (void)countUnreadItemsWithCallback:(LongBlock)callback;

@end
