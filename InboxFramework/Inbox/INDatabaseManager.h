//
//  INDatabaseManager.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDatabase.h>
#import <FMDB/FMDatabaseQueue.h>
#import <FMDB/FMResultSet.h>
#import "INModelObject.h"


@protocol INDatabaseObserver <NSObject>
@required
/**
 The INDatabaseManager has committed one or more objects to the local datastore.
*/
- (void)managerDidPersistModels:(NSArray *)models;
/**
 The INDatabaseManager has removed one or more objects to the local datastore.
 */
- (void)managerDidUnpersistModels:(NSArray*)models;
/**
 The INDatabaseManager has reset completely. Database observers should completely
 release and re-fetch any items drawn from the local cache.
 */
- (void)managerDidReset;
@end

/**
 The INDatabaseManager is responsible for maintaining a local cache of INModelObjects.
 It is built on top of FMDB (which is itself a wrapper on SQLite.) Objects are stored
 in the database in tables that are auto-generated for each class based on the class
 configuration.
 
 In each table, full JSON representations of objects are stored in a BLOB column called 'data'.
 Individual table columns and indexes are created for the properties returned from
 INModelObject -databaseIndexProperties. This means that queries for a particular class
 can only use the properties returned from -databaseIndexProperties, but also ensures
 that objects are stored in their entirety, queries only use indexed columns,
 and objects do not need to be separately transformed into an SQLite-friendly representatation
 for local storage.

 The INDatabaseManager is inspired by CoreData, and also by YapDatabase.
*/
@interface INDatabaseManager : NSObject
{
	NSMutableDictionary * _initializedModelClasses;
	dispatch_queue_t _queryDispatchQueue;
}

@property (nonatomic, strong, readonly) FMDatabaseQueue * queue;
@property (nonatomic, strong, readonly) NSHashTable * observers;


+ (INDatabaseManager *)shared;

/**
 Clear the entire local cache by destroying the database file.
*/
- (void)resetDatabase;

/**
 Register for updates when objects are added and removed from the database cache.
 The INDatabaseManager uses weak references, so it's not necessary to unregister
 as an observer.
 
 @param observer The object that would like to observe the database for changes.
*/
- (void)registerCacheObserver:(NSObject <INDatabaseObserver> *)observer;

/**
 Save or update a single INModelObject in the local database.
 This method notifies observers that the model has been stored.

 @param model The model to be saved to the database.
*/
- (void)persistModel:(INModelObject *)model;

/**
 Save or update a set of INModelObjects in a single database transaction. This is the
 preferred way of persisting multiple models, and you should try to use this method 
 whenever possible.

 This method notifies observers that the models have been stored.
 
 @param models An array of INModelObjects of the same class.
*/
- (void)persistModels:(NSArray *)models;

/**
 Remove an object from the local database cache and notify observers of the change.
 This method calls willUnpersist: on the model, removes it and any child rows in 
 associated tables, and then calls didUnpersist:.
 
 @param model The object to remove.

 @param willResave Pass YES if you will resave this model immediately, for example,
 if you are clearing the model from the cache, changing it's ID, and then resaving it.
 */
- (void)unpersistModel:(INModelObject *)model willResaveSameModel:(BOOL)willResave;

/**
 Remove a set of model objects from the database in a single database transaction. This is the
 preferred way of removing multiple models, and you should try to use this method
 whenever possible.
 
 @param models The objects to remove from the local cache.
 */
- (void)unpersistModels:(NSArray *)models;

/**
 Select a single instance from the local database cache and return it synchronously.
 
 @param ID an optional instance ID. If an instance ID is not provided, the first
 available instance of the class in the database will be returned.
 
 @return An instance of 'klass', or nil if a matching item was not found in the database.
*/
- (INModelObject*)selectModelOfClass:(Class)klass withID:(NSString*)ID;

/**
 Find models matching the provided predicate and return them, sorted by the sort descriptors.
 
 This method is asynchronous, and the callback will be invoked on the main thread when objects are ready.
 
 Note that predicates and sort descriptors should reference class properties, not the underlying
 database columns. ("namespaceID", not "namespace_id"). The predicates and sort descriptors you
 create can only reference properties returned from [class databaseIndexProperties], which have 
 been indexed and have their own table columns under the hood, or [class databaseJoinTableProperties].
 
 @param klass The type of models. Must be a subclass of INModelObject.
 @param wherePredicate A comparison or compound NSPredicate.
 @param sortDescriptors One or more sort descriptors.
 @param limit The maximum number of objects to return.
 @param offset The initial offset into the results. Useful when paging.
 @param callback A block that accepts an array of INModelObjects. At this time, the callback is called synchronously.
*/
- (void)selectModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate sortedBy:(NSArray *)sortDescriptors limit:(NSUInteger)limit offset:(NSUInteger)offset withCallback:(ResultsBlock)callback;

/**
Find models using the provided query and query parameters (substitutions for :foo, :bar in the query string).
This is a more direct version of -selectModelsOfClass:matching:sortedBy:limit:offset:withCallback;

 This method is asynchronous, and the callback will be invoked on the main thread when objects are ready.
*/
- (void)selectModelsOfClass:(Class)klass withQuery:(NSString *)query andParameters:(NSDictionary *)arguments andCallback:(ResultsBlock)callback;

/**
Find models using the provided query and query parameters (substitutions for :foo, :bar in the query string).
This method is synchronous, and the callbackwill be invoked immediately on the main thread. This is useful for 
some cases, but should be used with care.
*/
- (void)selectModelsOfClassSync:(Class)klass withQuery:(NSString *)query andParameters:(NSDictionary *)arguments andCallback:(ResultsBlock)callback;

/**
Find the number of models that match a particular query, synchronously.

 @param klass The type of models. Must be a subclass of INModelObject.
 @param wherePredicate A comparison or compound NSPredicate.
*/
- (void)countModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate withCallback:(LongBlock)callback;


@end
