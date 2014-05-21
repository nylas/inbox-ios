//
//  INSendDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSendDraftChange.h"
#import "INDeleteDraftChange.h"
#import "INTag.h"

@implementation INSendDraftChange


- (id)initWithModel:(INModelObject *)model
{
    self = [super initWithModel: model];
    if (self) {
        [[self tagIDsToRemove] addObject: INTagIDDraft];
        [[self tagIDsToAdd] addObject: INTagIDSent];
    }
    return self;
}

- (BOOL)canStartAfterChange:(INModelChange *)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftChange class]])
        return NO;
    return YES;
}

- (BOOL)canCancelPendingChange:(INModelChange*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftChange class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftChange class]])
        return YES;
    return NO;
}

- (BOOL)dependentOnChangesIn:(NSArray*)others
{
	for (INModelChange * other in others) {
		if ([other isKindOfClass: [INSaveDraftChange class]] && [[other model] isEqual: [self model]])
			return YES;
	}
	return NO;
}

@end
