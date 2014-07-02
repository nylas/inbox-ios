//
//  INDraft.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INFile.h"

typedef enum : NSUInteger {
    INDraftStateUnsent,
    INDraftStateSending,
    INDraftStateSendingFailed,
    INDraftStateSent
} INDraftState;

/**
Drafts are messages that may be sent, saved, and deleted. You can create new drafts
using one of the designated initializers, save them, add attachments, and send them using
the methods documented below. The Inbox framework takes care of persisting pending
draft operations, ensuring that -save, -send and other methods are eventually persistent,
even if they are called when the user is offline.

To list drafts available in a namespace, retrieve an INMessageProvider from the namespace.

Drafts receive a new ID each time they are saved. If your application is presenting a draft,
be prepared for the draft's ID to change after calls to -save. You can monitor changes all
Inbox objects by subscribing to INModelObjectChangedNotification.
*/
@interface INDraft : INMessage

@property (nonatomic, strong) NSString * internalState;

/*
 Initialize a new draft for sending a new message in the specified namespace.
 @return An initalized instance of INDraft
*/
- (id)initInNamespace:(INNamespace*)namespace;

/*
 Initialize a new draft for replying to an existing thread. It's important to use
 this initializer when replying so the Inbox API can properly append the draft to
 the existing thread.

 @param The namespace to create the draft in
 @param The thread that this draft is being created in reply to.
 @return An initalized instance of INDraft
 */
- (id)initInNamespace:(INNamespace*)namespace inReplyTo:(INThread*)thread;

/**
 Add an attachment to the thread. The attachment does not need to be fully uploaded
 to be attached to a draft. However, you should call [INFile upload] to start
 the upload process before adding the attachment to the draft.

 If attachments are still uploading when you call -save, the draft will not be 
 saved to the server until attachments have finished uploading.

 @param attachment The INAttachment object to add to the draft.
*/
- (void)addAttachment:(INFile*)attachment;

/**
 Add an attachment to the thread at a particular index.
 @param attachment The INAttachment object to add to the draft.
 @param index The index where the draft should be attached.
*/
- (void)addAttachment:(INFile*)attachment atIndex:(NSInteger)index;

/**
 Remove the provided attachment from the draft. Note that you need to call -save
 to commit your changes to Inbox after modifying the draft.

 @param attachment The attachment to remove from the draft.
*/
- (void)removeAttachment:(INFile*)attachment;

/**
 Remove the provided attachment from the draft. Note that you need to call -save
 to commit your changes to Inbox after modifying the draft.

 @param index The index of the attachment to remove from the draft.
 */
- (void)removeAttachmentAtIndex:(NSInteger)index;

/**
 Called internally when an attachment has finished uploading and it's ID has changed.
 @param ID The ID that was initially assigned to the INFile.
 @param uploadedID The ID assigned by the server that now represents the INFile.
*/
- (void)attachmentWithID:(NSString*)ID uploadedAs:(NSString*)uploadedID;

/**
The current state of the draft. See INDraftState for a list of available states.
*/
- (INDraftState)state;

#pragma mark Operations on Drafts

/**
 Save the draft. This method updates the local cache to reflect
 the change immediately but may be performed later on the Inbox server if an internet
 connection is not available.
 
 If you've added attachments to the draft and attachments are still uploading, the
 draft will not be saved to the server until attachment uploads are complete.
*/
- (void)save;

/**
 Send the draft. This method is eventually persistent and may
 be performed later if an internet connection is not available.
 
 Drafts will not be sent until all pending saves are complete and attachments have
 been uploaded. It's safe to call -save and -send back to back
 */
- (void)send;

/**
 Delete the draft. This method updates the local cache to reflect
 the change immediately but may be performed later on the Inbox server if an internet
 connection is not available.
 
 Deleting a draft will cancel any pending save or send operations.
*/
- (void)delete;

@end
