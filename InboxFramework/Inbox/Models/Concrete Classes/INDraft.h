//
//  INDraft.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INAttachment.h"

typedef enum : NSUInteger {
    INDraftStateUnsent,
    INDraftStateSending,
    INDraftStateSendingFailed,
    INDraftStateSent
} INDraftState;

@interface INDraft : INMessage

@property (nonatomic, strong) NSString * internalState;

- (id)initInNamespace:(INNamespace*)namespace;
- (id)initInNamespace:(INNamespace*)namespace inReplyTo:(INThread*)thread;

- (void)addAttachment:(INAttachment*)attachment;
- (void)addAttachment:(INAttachment*)attachment atIndex:(NSInteger)index;
- (void)removeAttachment:(INAttachment*)attachment;
- (void)removeAttachmentAtIndex:(NSInteger)index;

- (void)attachmentWithID:(NSString*)ID uploadedAs:(NSString*)uploadedID;

- (INDraftState)state;

#pragma mark Operations on Drafts

- (void)save;
- (void)send;
- (void)delete;

@end
