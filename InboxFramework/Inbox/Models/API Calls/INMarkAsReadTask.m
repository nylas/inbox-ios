//
//  INMarkAsReadTask.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/27/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMarkAsReadTask.h"

@implementation INMarkAsReadTask

- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDUnread];
    }
    return self;
}


- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    return NO;
}

@end
