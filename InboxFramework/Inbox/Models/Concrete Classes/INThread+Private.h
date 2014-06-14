//
//  INThread+Private.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INThread.h"

@interface INThread (Private)

- (void)addDraftID:(NSString*)draftID;
- (void)removeDraftID:(NSString*)draftID;


@end
