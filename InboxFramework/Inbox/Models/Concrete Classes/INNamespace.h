//
//  INNamespace.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelProvider.h"

@class INThreadProvider;
@class INMessageProvider;

/**
Namespaces are an important concept in Inbox. Typically, a user authenticates with
the Inbox API and the access token you are given provides access to one namespace:
the user's email account. Threads, messages, contacts, files, etc. live within the
namespace, and the INNamespace object provides convenience methods for creating
model providers for these types. You can also use the properties on INNamespace
to determine the user's email address, check Inbox sync status, and more.

Note: In the future, a single access token may grant you access to multiple namespaces,
and a namespace may not always be an entire email account.
*/
@interface INNamespace : INModelObject

@property (nonatomic, strong) NSString * emailAddress;
@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * provider;
@property (nonatomic, strong) NSString * status;
@property (nonatomic, strong) NSArray * scope;
@property (nonatomic, strong) NSDate * lastSync;

/**
 Initializes and returns a new INModelProvider for displaying contacts in this namespace.
 To display contacts matching certain criteria, create a new contact provider using this method
 and then set it's itemFilterPredicate to narrow the models it provides.
@return An initialized INModelProvider for displaying contacts.
*/
- (INModelProvider *)newContactProvider;

/**
 Initializes and returns a new INThreadProvider for displaying threads in this namespace.
 To display threads matching certain criteria, create a new thread provider using this method
 and then set it's itemFilterPredicate to narrow the models it provides.
 @return An initialized INThreadProvider for displaying threads.
 */
- (INThreadProvider *)newThreadProvider;

/**
 Initializes and returns a new INModelProvider for displaying tags in this namespace.
 @return An initialized INModelProvider for displaying tags.
 */
- (INModelProvider *)newTagProvider;

/**
 Initializes and returns a new INMessageProvider for displaying drafts in this namespace.
 @return An initialized INMessageProvider for displaying drafts.
 */
- (INMessageProvider *)newDraftsProvider;

/**
 Initializes and returns a new INMessageProvider for displaying messages in this namespace.
 Note that threads, not messages, are the objects you most often apply changes to. In many
 cases, you should use threads instead of messages. For example, you archive a thread, not
 a message.
 @return An initialized INMessageProvider for displaying messages.
 */
- (INMessageProvider *)newMessageProvider;

@end
