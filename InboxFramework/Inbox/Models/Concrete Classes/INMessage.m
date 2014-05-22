//
//  INMessage.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INThread.h"
#import "INAttachment.h"
#import "NSString+FormatConversion.h"
#import "INNamespace.h"
#import "INSaveDraftChange.h"
#import "INSendDraftChange.h"
#import "INDeleteDraftChange.h"

@implementation INMessage


+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
 	 @"subject": @"subject",
 	 @"body": @"body",
	 @"threadID": @"thread",
	 @"date": @"date",
	 @"from": @"from",
	 @"to": @"to",
	 @"attachmentIDs":@"attachments",
     @"isDraft": @"is_draft"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"messages";
}

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"threadID", @"subject", @"date"]];
}

- (id)initAsDraftIn:(INNamespace*)namespace
{
    NSAssert(namespace, @"initAsDraftIn: called with a nil namespace.");
    INMessage * m = [[INMessage alloc] init];
    [m setIsDraft: YES];
    [m setFrom: @[@{@"email": [namespace emailAddress], @"name": [namespace emailAddress]}]];
    [m setNamespaceID: [namespace ID]];
    return m;
}

- (id)initAsDraftIn:(INNamespace*)namespace inReplyTo:(INThread*)thread
{
    NSAssert(namespace, @"initAsDraftIn: called with a nil namespace.");
    INMessage * m = [[INMessage alloc] initAsDraftIn: namespace];
    
    NSMutableArray * recipients = [NSMutableArray array];
    for (NSDictionary * recipient in [thread participants])
        if (![[[INAPIManager shared] namespaceEmailAddresses] containsObject: recipient[@"email"]])
            [recipients addObject: recipient];
    
    [m setTo: recipients];
    [m setIsDraft: YES];
    [m setFrom: @[@{@"email": [namespace emailAddress], @"name": [namespace emailAddress]}]];
    [m setSubject: thread.subject];
    [m setThreadID: [thread ID]];
    
    return m;
    
}

- (INThread*)thread
{
    if (!_threadID)
        return nil;
    return [INThread instanceWithID: [self threadID] inNamespaceID: [self namespaceID]];
}

- (NSArray*)attachments
{
	NSMutableArray * attachments = [NSMutableArray array];
	for (NSString * ID in _attachmentIDs) {
		INAttachment * attachment = [INAttachment instanceWithID:ID inNamespaceID:[self namespaceID]];
		[attachments addObject: attachment];
	}
	return attachments;
}

- (void)addAttachment:(INAttachment*)attachment
{
	[self addAttachment:attachment atIndex:0];
}

- (void)addAttachment:(INAttachment*)attachment atIndex:(NSInteger)index
{
	NSMutableArray * IDs = [_attachmentIDs mutableCopy];
	if (!IDs) IDs = [NSMutableArray array];
	if (![IDs containsObject: [attachment ID]])
		[IDs insertObject:[attachment ID] atIndex: index];
	_attachmentIDs = IDs;
}

- (void)removeAttachment:(INAttachment*)attachment
{
	NSMutableArray * IDs = [_attachmentIDs mutableCopy];
	[IDs removeObject: [attachment ID]];
	_attachmentIDs = IDs;
}

- (void)removeAttachmentAtIndex:(NSInteger)index
{
	NSMutableArray * IDs = [_attachmentIDs mutableCopy];
	[IDs removeObjectAtIndex: index];
	_attachmentIDs = IDs;
}

#pragma mark Operations on Drafts

- (void)save
{
	NSAssert([self isDraft], @"Only draft messages can be saved.");

	INSaveDraftChange * save = [INSaveDraftChange operationForModel: self];
	[[INAPIManager shared] queueChange: save];
}

- (void)send
{
	NSAssert([self isDraft], @"Only draft messages can be sent.");
	
	INSendDraftChange * send = [INSendDraftChange operationForModel: self];
	[[INAPIManager shared] queueChange: send];
}

- (void)delete
{
	NSAssert([self isDraft], @"Only draft messages can be deleted.");

	INDeleteDraftChange * delete = [INDeleteDraftChange operationForModel: self];
	[[INAPIManager shared] queueChange: delete];
}

@end
