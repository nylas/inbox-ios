//
//  INUnarchiveThreadChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INUnarchiveThreadChange.h"
#import "INArchiveThreadChange.h"

@implementation INUnarchiveThreadChange

- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDArchive];
        [[self tagIDsToAdd] addObject: INTagIDInbox];
    }
    return self;
}


- (BOOL)canCancelPendingChange:(INModelChange*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INArchiveThreadChange class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INUnarchiveThreadChange class]])
        return YES;
    return NO;
}

@end
