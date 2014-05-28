//
//  INThreadProvider.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelProvider.h"
#import "INNamespace.h"

@interface INThreadProvider : INModelProvider

/*
@param namespaceID The namespace to fetch threads for. To fetch a subset of
the threads in the namespace, set the model provider's itemFilterPredicate.

@return An initialized INThreadProvider for threads in the given namespace.
*/
- (id)initWithNamespaceID:(NSString *)namespaceID;

/*
Count the number of unread threads in this provider's collection. This method
returns the number of threads matching the itemFilterPredicate that also have the
unread tag, and does not apply the provider's itemRange, giving a total number
of unread threads, not just the ones that are currently being provided to the delegate.

@param callback A block to be called when the unread count is determined. The 
block will be called on the main thread asynchronously.
*/
- (void)countUnreadItemsWithCallback:(LongBlock)callback;

@end
