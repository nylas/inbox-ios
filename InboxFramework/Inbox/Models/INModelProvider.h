//
//  INModelView.h
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INDatabaseManager.h"

@class INNamespace;

typedef enum : NSUInteger {
	INModelProviderCacheOnly,
	INModelProviderCacheThenNetwork
} INModelProviderCachePolicy;

typedef enum : NSUInteger {
	INModelProviderChangeAdd,
	INModelProviderChangeRemove,
	INModelProviderChangeUpdate
} INModelProviderChangeType;


/**
 An instance of INModelProviderChange encapsulates a single change to the items
 provided by an INModelProvider. You can use the information in an INModelProviderChange to
 update your UI in a granular way, ie. updating a particlar message row rather than refreshing
 the entire view.
 
 To get a changes, implement INModelProvider's -provider:dataAltered: delegate method.
*/
@interface INModelProviderChange : NSObject
@property (nonatomic, assign) INModelProviderChangeType type;
@property (nonatomic, strong) INModelObject * item;
@property (nonatomic, assign) NSInteger index;

/** 
  Creates and returns a new INModelProviderChange object for representing a particular change.
*/
+ (INModelProviderChange *)changeOfType:(INModelProviderChangeType)type forItem:(INModelObject *)item atIndex:(NSInteger)index;
@end

/**
 INModelProviderChangeSet is a lightweight wrapper around a set of changes
 to the items array provided by an INModelProvider. You can use information
 provided in the change set to intelligently update your interface in response
 to the items array changing, rather than reloading the entire UI.
*/
@interface INModelProviderChangeSet : NSObject
@property (nonatomic, strong) NSArray * changes;

/**
 Returns an array of index paths for rows that have changed in a particular way. 
 Note that this function assumes your UITableView or UICollectionView only has 
 one section. If you want to pass a section, use -indexPathsFor:assumingSection:
 
 @param changeType The type of change you want index paths for.
 @return An array of index paths.
*/
- (NSArray*)indexPathsFor:(INModelProviderChangeType)changeType;


/**
 Equivalent to indexPathsFor:, but returned NSIndexPath objects have the section value you provide.
 
 @param changeType The type of change you want index paths for.
 @param section The section you are displaying this provider in.
 @return An array of index paths.
 */
- (NSArray*)indexPathsFor:(INModelProviderChangeType)changeType assumingSection:(int)section;

@end

@class INModelProvider;

@protocol INModelProviderDelegate <NSObject>
@optional
/**
 Called when the items array of the provider has changed substantially. You should
 refresh your interface completely to reflect the new items array.
*/
- (void)providerDataChanged:(INModelProvider*)provider;

/**
 Called when objects have been added, removed, or modified in the items array, usually
 as a result of new data being fetched from the Inbox API or published on a real-time 
 connection. You may choose to refresh your interface completely or apply the individual
 changes provided in the changeSet.
 
 @param changeSet The set of items and indexes that have been modified.
 */
- (void)provider:(INModelProvider*)provider dataAltered:(INModelProviderChangeSet *)changeSet;

/**
 Called when an attempt to load data from the Inbox API has failed. If you requested
 the fetch by calling -refresh on the model provider or modifying the sort descriptors
 or filter predicate, you may want to display the error provided.

 @param error The error, with a display-ready message in -localizedDescription.
*/
- (void)provider:(INModelProvider*)provider dataFetchFailed:(NSError *)error;

/**
 Called when the provider has fully refresh in response to an explicit refresh request
 or a change in the item filter predicate or sort descriptors.
*/
- (void)providerDataFetchCompleted:(INModelProvider*)provider;

@end

/**
 INModelProvider allows you to display, filter, sort, and refresh collections of
 Inbox objects without worrying about complexities of the underlying cache and
 API.

 Providers expose a collection of items and a delegate protocol that allows you to
 update your interface when the collection of items changes.
 
 Providers retrieve items from the local cache and also initiate requests to the 
 Inbox API. When you set up a provider, you may receive several delegate calls
 as data is first retrieved from the cache and later merged with updated data
 provided by the API. It's important to implement -provider:dataAltered: so your
 controller can react to incremental changes in the provider's items array. In
 the future, the Inbox server will push data to your app, and -provider:dataAltered:
 may be called at any time.
*/
@interface INModelProvider : NSObject <INDatabaseObserver>
{
	NSPredicate * _underlyingPredicate;
	AFHTTPRequestOperation * _fetchOperation;
	BOOL _refetchRequested;
}

@property (nonatomic, strong) NSString * namespaceID;
@property (nonatomic, strong) Class modelClass;

@property (nonatomic, strong) NSArray * items;
@property (nonatomic, strong) NSPredicate * itemFilterPredicate;
@property (nonatomic, strong) NSArray * itemSortDescriptors;
@property (nonatomic, assign) NSRange itemRange;
@property (nonatomic, assign) INModelProviderCachePolicy itemCachePolicy;

@property (nonatomic, weak) NSObject <INModelProviderDelegate> * delegate;

/**
 Initialize a model provider for displaying a particular view of INModelObjects.
 
 @param modelClass The class of item you want to display. Must be a subclass of INModelObject.

 @param namespaceID The namespace of items you want to display.

 @param predicate An optional predicate that will be used, in addition to the itemFilterPredicate,
 when querying the local cache and the Inbox API. This predicate cannot be changed after the provider
 is created, and is used by factory methods to return an instance of INModelProvider scoped to the
 messages in a particular thread, for example.
 
 @return An instance of INModelProvider
*/
- (id)initWithClass:(Class)modelClass andNamespaceID:(NSString*)namespaceID andUnderlyingPredicate:(NSPredicate*)predicate;

/**
 Triggers a refresh of the items array. Depending on the itemCachePolicy you have chosen,
 this will fetch models from the local cache and/or the Inbox API. -refresh is called automatically
 when you modify the itemsFilterPredicate, itemRange or itemSortDescriptors.
*/
- (void)refresh;

/**
 @return YES if the provider is currently fetching items from the API. NO otherwise.
*/
- (BOOL)isRefreshing;

- (void)extendItemRange:(int)count;


@end
