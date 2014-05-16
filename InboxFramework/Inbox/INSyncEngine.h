//
//  INSyncEngine.h
//  BigSur
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol INSyncEngine <NSObject>

- (BOOL)providesCompleteCacheOf:(Class)klass;

@end
