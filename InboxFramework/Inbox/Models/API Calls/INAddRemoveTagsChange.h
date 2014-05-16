//
//  INAddRemoveTagsChange.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Inbox/Inbox.h>

@interface INAddRemoveTagsChange : INModelChange

- (NSMutableArray *)tagIDsToAdd;
- (NSMutableArray *)tagIDsToRemove;

@end
