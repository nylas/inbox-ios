//
//  INSaveDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSaveDraftChange.h"
#import "INThread.h"
#import "INTag.h"

@implementation INSaveDraftChange


- (NSURLRequest *)buildRequest
{
    NSAssert(self.model, @"INSaveDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INSaveDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * path = [NSString stringWithFormat:@"/n/%@/create_draft", [self.model namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];
    
    NSMutableDictionary * params = [[self.model resourceDictionary] mutableCopy];
    INThread * thread = [(INMessage*)self.model thread];
    
    NSMutableArray * messageIDs = [[thread messageIDs] mutableCopy];
    [messageIDs removeObject: [self.model ID]];
    if ([messageIDs count] > 1)
        [params setObject:[thread ID] forKey:@"reply_to"];
    
    return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:params error:&error];
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
    
    // Until we're able to save the draft, it's orphaned because it has no thread.
    // In order to present it in the app and give it the draft tag, let's create a
    // thread with a self-assigned ID for it. We'll keep that thread object in sync
    // and when this operation succeeds we'll destroy it.
    INThread * thread = [message thread];
    BOOL createThread = (thread == nil);
    
    if (createThread) {
        thread = [[INThread alloc] init];
        [thread setNamespaceID: [message namespaceID]];
        [thread setCreatedAt: [NSDate date]];
        [message setThreadID: [thread ID]];
    }

    [[INDatabaseManager shared] persistModel: message];

    if (createThread || [thread isUnsynced]) {
        [thread setSubject: [message subject]];
        [thread setParticipants: [message to]];
        [thread setTagIDs: @[INTagIDDraft]];
        [thread setSnippet: [message body]];
        [thread setMessageIDs: @[[message ID]]];
        [thread setUpdatedAt: [NSDate date]];
        [thread setLastMessageDate: [NSDate date]];
        [[INDatabaseManager shared] persistModel: thread];
    }
}

@end
