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
@class INAttachment;

@interface INMessage : INModelObject

@property (nonatomic, strong) NSString * body;
@property (nonatomic, strong) NSDate * date;
@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * threadID;
@property (nonatomic, strong) NSArray * attachmentIDs;
@property (nonatomic, strong) NSArray * from;
@property (nonatomic, strong) NSArray * to;

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


@end
