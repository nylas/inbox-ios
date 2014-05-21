//
//  INArchiveThreadChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INArchiveThreadChange.h"
#import "INTag.h"

@implementation INArchiveThreadChange

- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDInbox];
        [[self tagIDsToAdd] addObject: INTagIDArchive];
    }
    return self;
}

@end
