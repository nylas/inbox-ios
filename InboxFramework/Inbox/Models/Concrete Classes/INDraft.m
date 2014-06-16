//
//  INDraft.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INDraft.h"
#import "INNamespace.h"
#import "INThread.h"
#import "INSaveDraftTask.h"
#import "INSendDraftTask.h"
#import "INDeleteDraftTask.h"
#import "INUploadFileTask.h"

@implementation INDraft

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{ @"internalState": @"state" }];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"drafts";
}

- (id)initInNamespace:(INNamespace*)namespace
{
    NSAssert(namespace, @"initInNamespace: called with a nil namespace.");
    INDraft * m = [[INDraft alloc] init];
    [m setFrom: @[@{@"email": [namespace emailAddress], @"name": [namespace emailAddress]}]];
    [m setNamespaceID: [namespace ID]];
    [m setDate: [NSDate date]];
    return m;
}

- (id)initInNamespace:(INNamespace*)namespace inReplyTo:(INThread*)thread
{
    NSAssert(namespace, @"initInNamespace: called with a nil namespace.");
	NSAssert([thread isUnsynced] == NO, @"It looks like you're creating a new draft on a new thread. Instead of creating an INThread and then creating a draft on that thread, just create a new draft with [INDraft initInNamespace:]. A new thread will be created automatically when you send the draft!");
	
    INDraft * m = [[INDraft alloc] initInNamespace: namespace];
    
    NSMutableArray * recipients = [NSMutableArray array];
    for (NSDictionary * recipient in [thread participants])
        if (![[[INAPIManager shared] namespaceEmailAddresses] containsObject: recipient[@"email"]])
            [recipients addObject: recipient];
    
    [m setTo: recipients];
    [m setSubject: thread.subject];
    [m setThreadID: [thread ID]];
    
    return m;
}

- (void)addAttachment:(INFile*)attachment
{
	[self addAttachment:attachment atIndex:0];
}

- (void)addAttachment:(INFile*)attachment atIndex:(NSInteger)index
{
    NSMutableArray * IDs = [self.attachmentIDs mutableCopy];
    if (!IDs) IDs = [NSMutableArray array];
    if (![IDs containsObject: [attachment ID]])
        [IDs insertObject:[attachment ID] atIndex: index];
    self.attachmentIDs = IDs;

    if ([attachment isUnsynced]) {
        if (![attachment uploadTask])
            [attachment upload];

        // we can't save with this attachment ID. Find the attachment upload task
        // and tell it to update us when the draft upload has finished.
        [[[attachment uploadTask] waitingDrafts] addObject: self];
    }
}

- (void)removeAttachment:(INFile*)attachment
{
	NSMutableArray * IDs = [self.attachmentIDs mutableCopy];
	[IDs removeObject: [attachment ID]];
	self.attachmentIDs = IDs;

    [[[attachment uploadTask] waitingDrafts] removeObject: self];
}

- (void)removeAttachmentAtIndex:(NSInteger)index
{
    [self removeAttachment: [self.attachments objectAtIndex: index]];
}

- (void)attachmentWithID:(NSString*)ID uploadedAs:(NSString*)uploadedID
{
    NSMutableArray * IDs = [self.attachmentIDs mutableCopy];
    if ([IDs containsObject: ID])
        [IDs replaceObjectAtIndex:[IDs indexOfObject: ID] withObject:uploadedID];
    [self setAttachmentIDs: IDs];
}

- (INDraftState)state
{
    if ([_internalState isEqualToString: @"sending"])
        return INDraftStateSending;
    else if ([_internalState isEqualToString: @"sending_failed"])
        return INDraftStateSendingFailed;
    else if ([_internalState isEqualToString: @"sent"])
        return INDraftStateSent;
    return INDraftStateUnsent;
}

#pragma mark Operations on Drafts

- (void)save
{
	INSaveDraftTask * save = [INSaveDraftTask operationForModel: self];
	[[INAPIManager shared] queueTask: save];
}

- (void)send
{
	// Always save before sending, so the API consumer doesn't have to worry about it.
	// If they call -save themselves, this new INSaveDraftTask should invalidate the
	// other one and prevent a duplicate save anyway.
	[self save];
	
	INSendDraftTask * send = [INSendDraftTask operationForModel: self];
	[[INAPIManager shared] queueTask: send];
}

- (void)delete
{
	INDeleteDraftTask * delete = [INDeleteDraftTask operationForModel: self];
	[[INAPIManager shared] queueTask: delete];
}

@end
