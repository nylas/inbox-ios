//
//  INThread+Private.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread+Private.h"

@implementation INThread (Private)

- (void)removeDraftID:(NSString*)draftID
{
    NSMutableArray * IDs = [[self draftIDs] mutableCopy];
    [IDs removeObject: draftID];
    [self setDraftIDs: IDs];
}

- (void)addDraftID:(NSString*)draftID
{
    NSMutableArray * IDs = [[self draftIDs] mutableCopy];
    if (![IDs containsObject: draftID])
        [IDs addObject: draftID];
    [self setDraftIDs: IDs];
}

@end
