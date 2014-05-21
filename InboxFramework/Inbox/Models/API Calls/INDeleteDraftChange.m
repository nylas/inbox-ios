//
//  INDeleteDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INDeleteDraftChange.h"

@implementation INDeleteDraftChange

- (BOOL)canCancelPendingChange:(INModelChange*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSaveDraftChange class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftChange class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftChange class]])
        return YES;
    return NO;
}

- (BOOL)canStartAfterChange:(INModelChange*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftChange class]])
        return NO;
    return YES;
}

- (NSURLRequest *)buildRequest
{
    NSAssert(self.model, @"INDeleteDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INDeleteDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * url = [[NSURL URLWithString:[self.model resourceAPIPath] relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"DELETE" URLString:url parameters:nil error:&error];
}

- (void)startWithCallback:(CallbackBlock)callback
{
    // If we're deleting a draft that was never synced to the server, there's no need for
    // an API call. Just return.
    if ([self.model isUnsynced])
        callback(self, YES);
    else
        [super startWithCallback: callback];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    INMessage * message = (INMessage *)[self model];
    INThread * oldThread = [message thread];
    
    if ([responseObject isKindOfClass: [NSDictionary class]])
        [message updateWithResourceDictionary: responseObject];
    
    // if we've orphaned a temporary thread object, go ahead and clean it up
    if ([[oldThread ID] isEqualToString: [[message thread] ID]] == NO) {
        if ([oldThread isUnsynced])
            [[INDatabaseManager shared] unpersistModel: oldThread];
    }
    
    // if we've created a new thread, fetch it so we have more than it's ID
    if ([[message thread] namespaceID] == nil)
        [[message thread] reload: NULL];
}

- (void)applyLocally
{
    INMessage * message = (INMessage *)[self model];
    INThread * thread = [message thread];
    [[INDatabaseManager shared] unpersistModel: message];
    
    if (thread) {
        NSMutableArray * messageIDs = [[thread messageIDs] mutableCopy];
        [messageIDs removeObject: [self.model ID]];
        
        if ([messageIDs count]) {
            // remove the message from the message IDs
            [thread setMessageIDs: messageIDs];

            // remove the draft tag from the tag IDs
            NSMutableArray * tagIDs = [[thread tagIDs] mutableCopy];
            [tagIDs removeObject: INTagIDDraft];
            [thread setTagIDs: tagIDs];
            
            // save the thread
            [[INDatabaseManager shared] persistModel: thread];
        } else {
            // destroy the thread
            [[INDatabaseManager shared] unpersistModel: thread];
        }
    }
}

- (void)rollbackLocally
{
    INMessage * message = (INMessage *)[self model];
    [[INDatabaseManager shared] persistModel: message];
    
    INThread * thread = [message thread];
    if ([thread isUnsynced]) {
        [thread setSubject: [message subject]];
        [thread setParticipants: [message to]];
        [thread setTagIDs: @[INTagIDDraft]];
        [thread setSnippet: [message body]];
        [thread setUpdatedAt: [NSDate date]];
        [thread setLastMessageDate: [NSDate date]];
    }
    
    NSMutableArray * messageIDs = [[thread messageIDs] mutableCopy];
    [messageIDs addObject: [self.model ID]];
    [thread setMessageIDs: messageIDs];
    [[INDatabaseManager shared] persistModel: thread];
}

@end
