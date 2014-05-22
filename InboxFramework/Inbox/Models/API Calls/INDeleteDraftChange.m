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
	// If the other operation is sending the draft, it's too late!
	// Gotta tell the user the draft couldn't be deleted.
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftChange class]])
        return NO;
    return YES;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert(self.model, @"INDeleteDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INDeleteDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * url = [[NSURL URLWithString:[self.model resourceAPIPath] relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"DELETE" URLString:url parameters:nil error:&error];
}

- (void)applyLocally
{
    INMessage * message = (INMessage *)[self model];
    INThread * thread = [message thread];
    
	// destroy our message model locally
	[[INDatabaseManager shared] unpersistModel: message];

	// compute the message IDs that will be on our thread
	// now that this message is gone.
	NSMutableArray * messageIDs = [[thread messageIDs] mutableCopy];
	[messageIDs removeObject: [self.model ID]];

	if ([messageIDs count]) {
		// remove our message from the list of messages
		[thread setMessageIDs: messageIDs];

		// remove the draft tag
		NSMutableArray * tagIDs = [[thread tagIDs] mutableCopy];
		[tagIDs removeObject: INTagIDDraft];
		[thread setTagIDs: tagIDs];
		
		// save the thread
		[[INDatabaseManager shared] persistModel: thread];
	} else {

		// destroy the thread. We just removed the last message.
		[[INDatabaseManager shared] unpersistModel: thread];
	}
}

- (void)applyRemotelyWithCallback:(CallbackBlock)callback
{
    // If we're deleting a draft that was never synced to the server, there's no need for
    // an API call. Just return.
    if ([self.model isUnsynced])
        callback(self, YES);
    else
        [super applyRemotelyWithCallback: callback];
}

- (void)rollbackLocally
{
	// re-persist the message to the database
    INMessage * message = (INMessage *)[self model];
    [[INDatabaseManager shared] persistModel: message];
    
	// create our parent thread (if necessary) and populate it if it's unsynced
    INThread * thread = [message thread];
    if ([thread isUnsynced]) {
        [thread setSubject: [message subject]];
        [thread setParticipants: [message to]];
        [thread setSnippet: [message body]];
        [thread setUpdatedAt: [NSDate date]];
        [thread setLastMessageDate: [NSDate date]];
    }
    
	// add the draft tag to the thread
	NSMutableArray * tagIDs = [[thread tagIDs] mutableCopy];
	[tagIDs addObject: INTagIDDraft];
	[thread setTagIDs: tagIDs];
	
	// add the message to it's parent thread
    NSMutableArray * messageIDs = [[thread messageIDs] mutableCopy];
    [messageIDs addObject: [self.model ID]];
    [thread setMessageIDs: messageIDs];
    [[INDatabaseManager shared] persistModel: thread];
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


@end
