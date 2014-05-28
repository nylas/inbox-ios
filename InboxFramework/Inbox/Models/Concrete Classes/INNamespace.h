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

@interface INNamespace : INModelObject

@property (nonatomic, strong) NSString * emailAddress;
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

@end
