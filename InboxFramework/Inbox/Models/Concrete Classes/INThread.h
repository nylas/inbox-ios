//
//  INThread.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelProvider.h"
#import "INMessageProvider.h"
#import "INMessage.h"
#import "INDraft.h"

@class INTag;

@interface INThread : INModelObject

@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * snippet;
@property (nonatomic, strong) NSArray * participants;
@property (nonatomic, strong) NSDate * lastMessageDate;
@property (nonatomic, strong) NSArray * messageIDs;
@property (nonatomic, strong) NSArray * draftIDs;
@property (nonatomic, strong) NSArray * tagIDs;
@property (nonatomic, assign) BOOL unread;

/*
@return An array of INTag objects for the tags on this thread.
*/
- (NSArray*)tags;

/*
 @return An array of NSString tag IDs for the tags on this thread.
 */
- (NSArray*)tagIDs;

/*
 @param ID The ID to check for.
 @return YES if this thread has a tag with the given ID.
 */
- (BOOL)hasTagWithID:(NSString*)ID;

/**
 Initializes and returns a new INModelProvider for displaying messages in this thread.
 To further filter the messages (for example, to show just messages with attachments in
 the thread), you can set the itemFilterPredicate on the returned provider.
 
 @return An initialized INModelProvider for displaying messages.
 */
- (INMessageProvider*)newMessageProvider;

/**
 Initializes and returns a new INModelProvider for displaying drafts on this thread.
 @return An initialized INModelProvider for displaying drafts.
 */
- (INMessageProvider*)newDraftProvider;

#pragma mark Operations on Threads

/**
 Archive the thread. This method updates the local cache to reflect the change 
 immediately but may be performed later on the Inbox server if an internet
 connection is not available.
 */
- (void)archive;

/**
 Unarchive the thread. This method updates the local cache to reflect the change
 immediately but may be performed later on the Inbox server if an internet
 connection is not available.
 */
- (void)unarchive;

/**
 Mark this thread as read. This method removes the 'unread' tag, and marks every
 message in the thread as read. If the thread does not have the unread tag, it
 has no effect.
 
 This method updates the local cache to reflect the change immediately but may be
 performed later on the Inbox server if an internet connection is not available.
 */
- (void)markAsRead;

/**
 Mark this thread as seen. You should mark threads as "seen" as soon as the user
 views any part of the thread, or sees the thread subject and snippet onscreen.
 This indicates that the user has seen the thread and the thread should not be 
 presented as "new" from another device or application. If the thread does not have
 the unseen tag, this method has no effect.
 
 Your application should use the unseen tag, rather than the unread tag, to highlight
 new threads the user may be interested in.
 
 Additional notes:
 - Threads become "unseen" again if new messages arrive in the thread.
 - Threads become seen automatically if you mark any of their messages as read.
 
 This method updates the local cache to reflect the change immediately but may be
 performed later on the Inbox server if an internet connection is not available.
 */
- (void)markAsSeen;

/** 
 Star the thread. On some email platforms, this is known as 'flagging'.

 This method updates the local cache to reflect the change immediately but may be
 performed later on the Inbox server if an internet connection is not available.
*/
- (void)star;

/**
 Unstar the thread. On some email platforms, this is known as 'unflagging'.
 
 This method updates the local cache to reflect the change immediately but may be
 performed later on the Inbox server if an internet connection is not available.
 */
- (void)unstar;


@end
