//
//  INDeleteDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INDeleteDraftTask.h"
#import "INThread+Private.h"
#import "INSaveDraftTask.h"
#import "INSendDraftTask.h"

@implementation INDeleteDraftTask

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSaveDraftTask class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftTask class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftTask class]])
        return YES;
    return NO;
}

- (BOOL)canStartAfterTask:(INAPITask*)other
{
	// If the other operation is sending the draft, it's too late!
	// Gotta tell the user the draft couldn't be deleted.
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftTask class]])
        return NO;
    return YES;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert(self.model, @"INDeleteDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INDeleteDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * url = [[NSURL URLWithString:[self.model resourceAPIPath] relativeToURL:[INAPIManager shared].AF.baseURL] absoluteString];
	return [[[[INAPIManager shared] AF] requestSerializer] requestWithMethod:@"DELETE" URLString:url parameters:nil error:&error];
}

- (void)applyLocally
{
    INDraft * draft = (INDraft *)[self model];
	[[INDatabaseManager shared] unpersistModel: draft willResaveSameModel: NO];

    INThread * thread = [draft thread];
    if (thread) {
        [thread removeDraftID: [draft ID]];
        [[INDatabaseManager shared] persistModel: thread];
    }
}

- (void)applyRemotelyWithCallback:(CallbackBlock)callback
{
    // If we're deleting a draft that was never synced to the server,
    // there's no need for an API call. Just return.
    if ([self.model isUnsynced])
        callback(self, YES);
    else
        [super applyRemotelyWithCallback: callback];
}

- (void)rollbackLocally
{
	// re-persist the message to the database
    INDraft * draft = (INDraft *)[self model];
    [[INDatabaseManager shared] persistModel: draft];
    
    INThread * thread = [draft thread];
    if (thread) {
        [thread addDraftID: [draft ID]];
        [[INDatabaseManager shared] persistModel: thread];
    }
}


@end
