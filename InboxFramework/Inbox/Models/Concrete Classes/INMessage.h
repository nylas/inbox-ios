//
//  INMessage.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"

@class INThread;
@class INNamespace;
@class INFile;

/** The INMessage class provides access to message attributes and convenience
methods for accessing attachments, marking as read, etc.

You should not create INMessage objects directly. You can fetch messages by
asking an INNamespace for a newMessageProvider and configuring that provider to
return the result set you want (for example, all unread messages.)

To compose or send a new message, create an instance of INDraft and call it's
-save and -send methods, respectively.

The Inbox platform is similar to Gmail in that many actions are taken on threads,
not on messages. If you're looking to archive, label, or delete a message, see
the documentation for INThread.
*/
@interface INMessage : INModelObject

@property (nonatomic, strong) NSString * body;
@property (nonatomic, strong) NSString * snippet;
@property (nonatomic, strong) NSDate * date;
@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * threadID;
@property (nonatomic, strong) NSArray * attachmentIDs;
@property (nonatomic, strong) NSArray * from;
@property (nonatomic, strong) NSArray * to;
@property (nonatomic, strong) NSArray * cc;
@property (nonatomic, strong) NSArray * bcc;
@property (nonatomic, assign) BOOL unread;

/*
 @return The parent thread of this message. Depending on how this message instance was
 loaded, the thread may or may not be available in the cache. After calling this method,
 you should check if the thread's data is loaded by calling -isDataAvailable, and call
 -reload: if necessary to fully populate the thread.
*/
- (INThread*)thread;

/*
 @return An array of INAttachment objects representing attachments to this message.
 Attachment objects can be queried for previews, download links, etc.
*/
- (NSArray*)attachments;

/*
 Mark the individual message as read. This change takes effect immediately in the local cache
 but may not sync back to the server immediately.
*/
- (void)markAsRead;

@end
