//
//  INModelView.m
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelProvider.h"
#import "INModelObject.h"
#import "INModelResponseSerializer.h"
#import "NSObject+AssociatedObjects.h"
#import "INSyncEngine.h"

@implementation INModelProviderChange : NSObject

+ (INModelProviderChange *)changeOfType:(INModelProviderChangeType)type forItem:(INModelObject *)item atIndex:(NSInteger)index
{
	NSAssert(index != NSNotFound, @"You cannot create a change for index = NSNotFound.");
	
	INModelProviderChange * change = [[INModelProviderChange alloc] init];
	[change setType:type];
	[change setItem:item];
	[change setIndex:index];
	return change;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"<INModelProviderChange: %p> type: %@, item: %@, index: %d", self, @[@"Add",@"Remove", @"Update"][_type], _item, (int)_index];
}

@end

@implementation INModelProviderChangeSet

- (NSArray*)indexPathsFor:(INModelProviderChangeType)changeType
{
    return [self indexPathsFor:changeType assumingSection:0];
}

- (NSArray*)indexPathsFor:(INModelProviderChangeType)changeType assumingSection:(int)section
{
	NSMutableArray * indexPaths = [NSMutableArray array];
	for (INModelProviderChange * change in self.changes) {
		if (change.type == changeType)
			[indexPaths addObject: [NSIndexPath indexPathForItem:change.index inSection:section]];
	}
	return indexPaths;
}

- (NSString*)description
{
	return [_changes description];
}
@end


@implementation INModelProvider

- (id)initWithClass:(Class)modelClass andNamespaceID:(NSString*)namespaceID andUnderlyingPredicate:(NSPredicate*)predicate
{
	NSAssert([modelClass isSubclassOfClass: [INModelObject class]], @"Only subclasses of INModelObject can be provided through INModelProviders.");

	self = [super init];
	if (self) {
		_modelClass = modelClass;
		_namespaceID = namespaceID;
		_underlyingPredicate = predicate;
		
        if ([[[INAPIManager shared] syncEngine] providesCompleteCacheOf: modelClass])
            _itemCachePolicy = INModelProviderCacheOnly;
        else
            _itemCachePolicy = INModelProviderCacheThenNetwork;
        
		_itemRange = NSMakeRange(0, 200);

		// subscribe to updates about the local database cache. This creates
		// a weak reference to us, so we don't have to worry about unregistering later.
		[[INDatabaseManager shared] registerCacheObserver:self];
	}
	return self;
}

- (void)setItemSortDescriptors:(NSArray *)sortDescriptors
{
	if ([sortDescriptors isEqual: _itemSortDescriptors])
		return;
	
	_itemSortDescriptors = sortDescriptors;
	[self empty];
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)setItemFilterPredicate:(NSPredicate *)predicate
{
	if ([predicate isEqual: _itemFilterPredicate])
		return;
		
	_itemFilterPredicate = predicate;
	[self empty];
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)setItemRange:(NSRange)itemRange
{
	if ((_itemRange.length == itemRange.length) && (_itemRange.location == itemRange.location))
		return;
		
	_itemRange = itemRange;
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)extendItemRange:(int)count
{
    [self setItemRange: NSMakeRange(_itemRange.location, _itemRange.length + count)];
}

- (void)empty
{
	if ([_items count] > 0) {
		self.items = @[];
		if ([self.delegate respondsToSelector:@selector(providerDataChanged:)])
			[self.delegate providerDataChanged:self];
	}
}

- (void)refresh
{
	[self fetchFromCache:^{
        if (_itemCachePolicy == INModelProviderCacheThenNetwork)
            [self fetchFromAPI];
    }];

	[self markPerformedSelector: @selector(refresh)];
}

- (BOOL)isRefreshing
{
	return (_fetchOperation || _refetchRequested);
}

- (NSPredicate*)fetchPredicate
{
	NSMutableArray * predicates = [NSMutableArray array];

	if (_namespaceID) [predicates addObject: [NSComparisonPredicate predicateWithFormat:@"namespaceID = %@", _namespaceID]];
	if (_underlyingPredicate) [predicates addObject: _underlyingPredicate];
	if (_itemFilterPredicate) [predicates addObject: _itemFilterPredicate];
	
	if ([predicates count] > 1)
		return [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:predicates];
	else
		return [predicates firstObject];
}

- (void)fetchFromCache:(VoidBlock)callback
{
	// immediately refresh our data from what is now available in the cache
	[[INDatabaseManager shared] selectModelsOfClass:_modelClass matching:[self fetchPredicate] sortedBy:_itemSortDescriptors limit:_itemRange.length offset:_itemRange.location withCallback:^(NSArray * matchingItems) {
		self.items = matchingItems;

 		NSAssert([NSThread isMainThread], @"INModelProvider delegate should never be called on a background thread.");
        if ([self.delegate respondsToSelector:@selector(providerDataChanged:)])
			[self.delegate providerDataChanged:self];

        if (callback)
            callback();
    }];
}

- (void)fetchFromAPI
{
	if (_fetchOperation) {
		_refetchRequested = YES;
		return;
	}
	NSDictionary * params = [self queryParamsForPredicate: [self fetchPredicate]];
	NSString * path = [_modelClass resourceAPIName];
	
	if (_namespaceID)
		path = [NSString stringWithFormat:@"/n/%@/%@", _namespaceID, path];

	_fetchOperation = [[INAPIManager shared].AF GET:path parameters:params success:^(AFHTTPRequestOperation * operation, NSArray * models) {
		NSLog(@"GET %@ (%@) RETRIEVED %lu %@s", path, [params description], (unsigned long)[models count], NSStringFromClass(_modelClass));

		// The response serializer automatically inflates the returned objects and
		// writes them to our local database. That database change propogates to us,
		// and we compute added / removed / updated models. BOOM. READ : No need to
        // update self.items
		_fetchOperation = nil;
		if (_refetchRequested) {
			_refetchRequested = NO;
			[self fetchFromAPI];
		}

 		NSAssert([NSThread isMainThread], @"INModelProvider delegate should never be called on a background thread.");
		if ([self.delegate respondsToSelector:@selector(providerDataFetchCompleted:)])
			[self.delegate providerDataFetchCompleted: self];
		
	} failure:^(AFHTTPRequestOperation * operation, NSError * error) {
 		NSAssert([NSThread isMainThread], @"INModelProvider delegate should never be called on a background thread.");
		_fetchOperation = nil;
		if ([self.delegate respondsToSelector:@selector(provider:dataFetchFailed:)])
			[self.delegate provider:self dataFetchFailed:error];
	}];
	
	INModelResponseSerializer * serializer = [[INModelResponseSerializer alloc] initWithModelClass: _modelClass];
    [serializer setModelsCurrentlyMatching: [NSArray arrayWithArray: self.items]];
	[_fetchOperation setResponseSerializer:serializer];
}

- (NSDictionary *)queryParamsForPredicate:(NSPredicate*)predicate
{
	return @{@"limit":@(_itemRange.length), @"offset":@(_itemRange.location)};
}

#pragma mark Receiving Updates from the Database

- (void)managerDidPersistModels:(NSArray *)affectedModels
{
	NSAssert([NSThread isMainThread], @"-managerDidPersistModels is not threadsafe.");
	
	// as an optimization, don't bother computing a change set if we don't
	// have any models or if our delegate isn't watching for change sets.
    // Just fetch matching models the easy way.
    BOOL resultSetEmpty = (self.items == nil);
    BOOL resultSetAlterationsConsumed = ([self.delegate respondsToSelector:@selector(provider:dataAltered:)]);
    
    if (resultSetEmpty || !resultSetAlterationsConsumed)
		return [self fetchFromCache:NULL];
    
    // determine if our result set contains any of the affected models, or if
    // they match our predicate. We may not need to run any updates!
    BOOL resultSetImpactedByModels = NO;
    NSPredicate * fetchPredicate = [self fetchPredicate];

	for (INModelObject * model in affectedModels) {
        if ([model isMemberOfClass: _modelClass] && (([fetchPredicate evaluateWithObject: model]) || ([self.items containsObject: model]))) {
            resultSetImpactedByModels = YES;
            break;
        }
    }
    if (!resultSetImpactedByModels)
        return;
    
    // Hit the database and then compare the new result set against our
    // existing result set to find changes.
    [self sendChangeSetForPersistedModels: affectedModels];
}


- (void)managerDidUnpersistModels:(NSArray*)models
{
	NSAssert([NSThread isMainThread], @"-managerDidUnpersistModels is not threadsafe.");

    // If no items were removed from our result set, bail early!
	if (!self.items || ![[NSSet setWithArray: self.items] intersectsSet: [NSSet setWithArray: models]])
        return;
    
	if ([self.delegate respondsToSelector:@selector(provider:dataAltered:)]) {
        [self sendChangeSetForPersistedModels: @[]];
        
	} else {
		[self fetchFromCache:NULL];
    }
}

- (void)managerDidReset
{
	NSAssert([NSThread isMainThread], @"-managerDidReset is not threadsafe.");
	[self refresh];
}


#pragma mark Helpers for Computing Change Sets

- (void)sendChangeSetForPersistedModels:(NSArray *)affectedModels
{
    // fetch a new set of items and compare them to find the items removed, added, modified.
    // We go back to the database, because the removal of an item means we need another item
    // to take it's spot in our set, etc. (Trust me, it's much easier to hit the database than
    // try to manually account for these scenarios...)
	[[INDatabaseManager shared] selectModelsOfClass:_modelClass matching:[self fetchPredicate] sortedBy:_itemSortDescriptors limit:_itemRange.length offset:_itemRange.location withCallback:^(NSArray * newItems) {
        NSMutableArray * changes = [NSMutableArray array];
        
        // find items that no longer exist in our result set
        for (int ii = 0; ii < [self.items count]; ii++) {
            INModelObject * item = [self.items objectAtIndex: ii];
            if (![newItems containsObject: item])
                [changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeRemove forItem:item atIndex: ii]];
        }
        
        // find added and modified items
        for (int ii = 0; ii < [newItems count]; ii++) {
            INModelObject * item = [newItems objectAtIndex: ii];
            
            if ([self.items containsObject: item]) {
                // the item hasn't been added or removed. was it modified?
                if ([affectedModels containsObject: item])
                    [changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeUpdate forItem:item atIndex:ii]];
                
            } else {
                // the item has been added to our result set
                [changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeAdd forItem:item atIndex:ii]];
            }
        }
        
        self.items = newItems;
        
        // only broadcast changes to our delegate if changes were actually made
        if ([changes count] > 0) {
            INModelProviderChangeSet * set = [[INModelProviderChangeSet alloc] init];
            [set setChanges: changes];
            [self.delegate provider:self dataAltered:set];
        }
    }];
}

@end
