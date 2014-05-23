//
//  INSaveDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSaveDraftTask.h"
#import "INThread.h"
#import "INThread+Private.h"
#import "INTag.h"
#import "INDeleteDraftTask.h"
#import "INSendDraftTask.h"
#import "INModelObject+Uniquing.h"


@implementation INSaveDraftTask

- (BOOL)canStartAfterTask:(INAPITask *)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftTask class]])
        return NO;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftTask class]])
        return NO;
    return YES;
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSaveDraftTask class]])
        return YES;
    return NO;
}

- (NSArray*)dependenciesIn:(NSArray *)others
{
	NSMutableArray * dependencies = [NSMutableArray array];
	INMessage * draft = (INMessage *)[self model];

	// are any requests uploading attachments that are referenced in our draft?
	// we need to wait for those to finish...
	for (INAPITask * other in others) {
		if ([other isKindOfClass: [INUploadAttachmentTask class]]
			&& [[draft attachmentIDs] containsObject: [[other model] ID]])
			[dependencies addObject: other];
	}
	
	return dependencies;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert(self.model, @"INSaveDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INSaveDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * path = nil;
    
    if ([self.model isUnsynced])
        path = [NSString stringWithFormat:@"/n/%@/drafts", [self.model namespaceID]];
    else
        path = [NSString stringWithFormat:@"/n/%@/drafts/%@", [self.model namespaceID], [self.model ID]];

    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];
    NSMutableDictionary * params = [[self.model resourceDictionary] mutableCopy];
    INThread * thread = [(INDraft*)self.model thread];
    if (thread) [params setObject:[thread ID] forKey:@"replying_to_thread"];
    
    return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:params error:&error];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    if (![responseObject isKindOfClass: [NSDictionary class]])
        return NSLog(@"SaveDraft weird response: %@", responseObject);
    
    INDraft * draft = (INDraft *)[self model];
    NSString * draftInitialID = [draft ID];

    // remove the draft from the local cache and then update it with the API response
    // and save it again. This is important, because the JSON that comes back gives the
    // draft a different ID and we want to replace the old draft since it's outdated.
    [[INDatabaseManager shared] unpersistModel: draft willResaveSameModel:YES completionBlock:^{
        [draft updateWithResourceDictionary: responseObject];
        [[INDatabaseManager shared] persistModel: draft];
        
        // if the draft ID changed, update our local cache so it has the new draft ID
        if (![draftInitialID isEqualToString: [draft ID]]) {
            INThread * thread = [draft thread];
            [thread removeDraftID: draftInitialID];
            [thread addDraftID: [draft ID]];
            [[INDatabaseManager shared] persistModel: thread];
        }
    }];
}

- (void)applyLocally
{
    INDraft * draft = (INDraft *)[self model];
    if ([draft thread]) {
        INThread * thread = [draft thread];
        [thread addDraftID: [draft ID]];
        [[INDatabaseManager shared] persistModel: thread];
    }

    [[INDatabaseManager shared] persistModel: draft];
}

- (void)rollbackLocally
{
	// we deliberately do not roll back draft saves. They shouldn't ever be rejected
	// by the server, and we don't want to loose people's data under any circumstance.
}

@end
