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
	[mapping addEntriesFromDictionary:@{ @"internalState": @"state", @"version": @"version" }];
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

- (void)addFile:(INFile*)file
{
	[self addFile:file atIndex:0];
}

- (void)addFile:(INFile*)file atIndex:(NSInteger)index
{
    NSMutableArray * files = [self.files mutableCopy];
    if (!files) files = [NSMutableArray array];
    if (![files containsObject: file])
        [files insertObject:file atIndex: index];
    self.files = files;
    
    if ([file isUnsynced]) {
        if (![file uploadTask])
            [file upload];

        // we can't save with this file ID. Find the file upload task
        // and tell it to update us when the draft upload has finished.
        [[[file uploadTask] waitingDrafts] addObject: self];
    }
}

- (void)removeFile:(INFile*)file
{
	NSMutableArray * files = [self.files mutableCopy];
	[files removeObject: file];
	self.files = files;

    [[[file uploadTask] waitingDrafts] removeObject: self];
}

- (void)removeFileAtIndex:(NSInteger)index
{
    [self removeFile: [self.files objectAtIndex: index]];
}

- (void)fileWithID:(NSString*)ID uploadedAs:(NSString*)uploadedID
{
    // No longer necessary, since the files array references the same
    // INFile objects that are being modified. Not refactoring this away
    // completely, because it may be useful in the future.
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
