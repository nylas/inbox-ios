//
//  INUnarchiveThreadChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INUnarchiveThreadTask.h"
#import "INArchiveThreadTask.h"
#import "INTag.h"

@implementation INUnarchiveThreadTask

- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDArchive];
        [[self tagIDsToAdd] addObject: INTagIDInbox];
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
