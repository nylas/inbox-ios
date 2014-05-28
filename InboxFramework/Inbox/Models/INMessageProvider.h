//
//  INMessageProvider.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelProvider.h"

@interface INMessageProvider : INModelProvider

/**
 @param threadID The thread ID to fetch messages for.
 @param namespaceID The namespace in which the thread lives.
 @return An INMessageProvider initialized for displaying messages.
*/
- (id)initForMessagesInThread:(NSString *)threadID andNamespaceID:(NSString*)namespaceID;

/**
 @param threadID The thread ID to fetch drafts for.
 @param namespaceID The namespace in which the thread lives.
 @return An INMessageProvider initialized for displaying drafts.
 */
- (id)initForDraftsInThread:(NSString *)threadID andNamespaceID:(NSString*)namespaceID;

@end
