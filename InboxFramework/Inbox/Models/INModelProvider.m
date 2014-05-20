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
	return [NSString stringWithFormat:@"<INModelProviderChange: %p> type: %d, item: %@, index: %d", self, _type, _item, _index];
}

@end

@implementation INModelProviderChangeSet

- (NSArray*)indexPathsFor:(INModelProviderChangeType)changeType
{
	NSMutableArray * indexPaths = [NSMutableArray array];
	for (INModelProviderChange * change in self.changes) {
		if (change.type == changeType)
			[indexPaths addObject: [NSIndexPath indexPathForItem:change.index inSection:0]];
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
        
		_itemRange = NSMakeRange(0, 1000);

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
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)setItemFilterPredicate:(NSPredicate *)predicate
{
	if ([predicate isEqual: _itemFilterPredicate])
		return;
		
	_itemFilterPredicate = predicate;
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)setItemRange:(NSRange)itemRange
{
	if ((_itemRange.length == itemRange.length) && (_itemRange.location == itemRange.location))
		return;
		
	_itemRange = itemRange;
	[self performSelectorOnMainThreadOnce:@selector(refresh)];
}

- (void)refresh
{
	[self fetchFromCache];

	// make an API request to refresh our data
	if (_itemCachePolicy == INModelProviderCacheThenNetwork)
		[self fetchFromAPI];
		
	[self markPerformedSelector: @selector(refresh)];
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

- (void)fetchFromCache
{
	// immediately refresh our data from what is now available in the cache
	[[INDatabaseManager shared] selectModelsOfClass:_modelClass matching:[self fetchPredicate] sortedBy:_itemSortDescriptors limit:_itemRange.length offset:_itemRange.location withCallback:^(NSArray * matchingItems) {
		self.items = matchingItems;

		if ([self.delegate respondsToSelector:@selector(providerDataChanged)])
			[self.delegate providerDataChanged];
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

	_fetchOperation = [[INAPIManager shared] GET:path parameters:params success:^(AFHTTPRequestOperation * operation, NSArray * models) {
		NSLog(@"GET %@ (%@) RETRIEVED %lu %@s", path, [params description], (unsigned long)[models count], NSStringFromClass(_modelClass));

		// The response serializer automatically inflates the returned objects and
		// writes them to our local database. That database change propogates to us,
		// and we compute added / removed / updated models. BOOM.
		_fetchOperation = nil;
		if (_refetchRequested) {
			_refetchRequested = NO;
			[self fetchFromAPI];
		}

		if ([self.delegate respondsToSelector:@selector(providerDataFetchCompleted)])
			[self.delegate providerDataFetchCompleted];
		
	} failure:^(AFHTTPRequestOperation * operation, NSError * error) {
		if ([self.delegate respondsToSelector:@selector(providerDataFetchFailed:)])
			[self.delegate providerDataFetchFailed:error];
		_fetchOperation = nil;
	}];
	
	INModelResponseSerializer * serializer = [[INModelResponseSerializer alloc] initWithModelClass: _modelClass];
	[_fetchOperation setResponseSerializer:serializer];
}

- (NSDictionary *)queryParamsForPredicate:(NSPredicate*)predicate
{
	return @{@"limit":@(_itemRange.length), @"offset":@(_itemRange.location)};
}

#pragma mark Receiving Updates from the Database

- (void)managerDidPersistModels:(NSArray *)savedArray
{
	NSAssert([NSThread isMainThread], @"-managerDidPersistModels is not threadsafe.");
	
	NSMutableSet * savedModels = [NSMutableSet set];
	for (INModelObject * model in savedArray)
		if ([model isKindOfClass: _modelClass])
			[savedModels addObject: model];

	if ([savedModels count] == 0) {
		return;
	}
	
	NSMutableSet * savedMatchingModels = [savedModels mutableCopy];
	NSSet * existingModels = [NSSet setWithArray: self.items];

	NSPredicate * fetchPredicate = [self fetchPredicate];
	if (fetchPredicate)
		[savedMatchingModels filterUsingPredicate: fetchPredicate];
	
	// compute the models that were added   (saved & matching - currently in our set)
	NSMutableSet * addedModels = [savedMatchingModels mutableCopy];
	[addedModels minusSet: existingModels];

	// compute the models that were changed (saved & matching - added)
	NSMutableSet * changedModels = [savedMatchingModels mutableCopy];
	[changedModels intersectSet: existingModels];
	[changedModels minusSet: addedModels];

	// compute the models that were changed and no longer match our predicate (in existing and not in matching)
	NSMutableSet * removedModels = [savedModels mutableCopy];
	[removedModels minusSet: savedMatchingModels];
	[removedModels intersectSet: existingModels];

	if (([addedModels count] == 0) && ([changedModels count] == 0) && ([removedModels count] == 0))
		return;

	// Add the addedModels to our cached set and then resort
	NSMutableArray * allItems = [self.items mutableCopy];

	// If our delegate wants to be notified of item-level changes, compute those. Please
	// note that this code was designed for readability over efficiency. If it's too slow
	// we'll come back to it :-)
	if ([self.delegate respondsToSelector:@selector(providerDataAltered:)] && ([self.items count] > 0)) {
		NSMutableArray * changes = [NSMutableArray array];
		
		for (INModelObject * item in removedModels) {
			NSInteger index = [allItems indexOfObjectIdenticalTo:item];
			[changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeRemove forItem:item atIndex:index]];
		}

		[allItems removeObjectsInArray: [removedModels allObjects]];
		[allItems addObjectsFromArray: [addedModels allObjects]];
		[allItems sortUsingDescriptors: self.itemSortDescriptors];
		
		NSArray * allItemsInRange = [allItems subarrayWithRange: NSMakeRange(MIN(_itemRange.location, [allItems count]-1), MIN(_itemRange.length, [allItems count] - _itemRange.location))];
		
		for (INModelObject * item in self.items) {
			if ([allItemsInRange indexOfObjectIdenticalTo:item] == NSNotFound) {
				NSInteger index = [self.items indexOfObjectIdenticalTo:item];
				[changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeRemove forItem:item atIndex:index]];
			}
		}

		self.items = allItemsInRange;
		
		for (INModelObject * item in addedModels) {
			NSInteger index = [_items indexOfObjectIdenticalTo:item];
			if (index != NSNotFound)
				[changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeAdd forItem:item atIndex:index]];
		}
		for (INModelObject * item in changedModels) {
			NSInteger index = [_items indexOfObjectIdenticalTo:item];
			if (index != NSNotFound)
				[changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeUpdate forItem:item atIndex:index]];
		}
		
		if ([changes count] > 0) {
			INModelProviderChangeSet * set = [[INModelProviderChangeSet alloc] init];
			[set setChanges: changes];
			[self.delegate providerDataAltered:set];
		}
								
	} else if ([self.delegate respondsToSelector:@selector(providerDataChanged)]) {
		[allItems addObjectsFromArray: [addedModels allObjects]];
		[allItems removeObjectsInArray: [removedModels allObjects]];
		[allItems sortUsingDescriptors:self.itemSortDescriptors];
		self.items = [allItems subarrayWithRange: NSMakeRange(MIN(_itemRange.location, [allItems count]-1), MIN(_itemRange.length, [allItems count] - _itemRange.location))];
		[self.delegate providerDataChanged];
	}
}

- (void)managerDidUnpersistModels:(NSArray*)models
{
	NSAssert([NSThread isMainThread], @"-managerDidUnpersistModels is not threadsafe.");

	NSMutableArray * newItems = [NSMutableArray arrayWithArray: self.items];
	[newItems removeObjectsInArray: models];
	
	if ([self.delegate respondsToSelector:@selector(providerDataAltered:)]) {
		NSMutableArray * changes = [NSMutableArray array];
		for (INModelObject * item in models) {
			NSInteger index = [self.items indexOfObjectIdenticalTo:item];
            if (index != NSNotFound)
                [changes addObject:[INModelProviderChange changeOfType:INModelProviderChangeRemove forItem:item atIndex:index]];
		}

		self.items = newItems;

		INModelProviderChangeSet * set = [[INModelProviderChangeSet alloc] init];
		[set setChanges: changes];
		[self.delegate providerDataAltered:set];

	} else if ([self.delegate respondsToSelector:@selector(providerDataChanged)]) {
		self.items = newItems;
		[self.delegate providerDataChanged];

	} else {
		self.items = newItems;
	}
}

- (void)managerDidReset
{
	NSAssert([NSThread isMainThread], @"-managerDidReset is not threadsafe.");
	[self refresh];
}

@end
