//
//  INMessageProvider.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelProvider.h"

@interface INMessageProvider : INModelProvider

- (id)initWithThreadID:(NSString *)threadID andNamespaceID:(NSString*)namespaceID;

@end
