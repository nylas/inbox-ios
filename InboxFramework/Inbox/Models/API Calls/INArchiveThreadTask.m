//
//  INArchiveThreadChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INArchiveThreadTask.h"
#import "INUnarchiveThreadTask.h"
#import "INTag.h"

@implementation INArchiveThreadTask

- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDInbox];
        [[self tagIDsToAdd] addObject: INTagIDArchive];
    }
    return self;
}


- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INArchiveThreadTask class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INUnarchiveThreadTask class]])
        return YES;
    return NO;
}

@end
