//
//  INAddRemoveTagsChange.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPITask.h"

@interface INAddRemoveTagsTask : INAPITask

- (NSMutableArray *)tagIDsToAdd;
- (NSMutableArray *)tagIDsToRemove;

@end
