//
//  INModelObject.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INAPIManager.h"

@class FMDatabase;
@class INAPITask;
@class INNamespace;

static NSString * INModelObjectChangedNotification = @"model_changed";

/**
 INModelObject is the base class for model objects in the Inbox framework. It provides
 core functionality related to object serialization and is intended to be subclassed.
*/
@interface INModelObject : NSObject <NSCoding>
{
    BOOL _isDataAvailable;
}
@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) NSString * namespaceID;
@property (nonatomic, strong) NSDate * createdAt;
@property (nonatomic, strong) NSDate * updatedAt;

#pragma Getting Instances

/** @name Retrieving Instances */

/**
 @param ID The ID of the model. Required.
 @param namespaceID The namespace ID the model should exist in. Required.

 @return An instance of the requested class. If a copy of this model is already in memory, this
 method returns the same instance. If it has been stored in the Inbox local cache, it will be
 retrieved from cache. If no copy of the object is available, an empty instance is returned.
 Subscribe to this instance to be notified when it's data becomes available and update your
 UI accordingly. 
 */
+ (id)instanceWithID:(NSString*)ID inNamespaceID:(NSString*)namespaceID;

/**
 @return NO if the model has been synced to the Inbox API. YES, if the ID of the object is
 self-assigned, indicating that it has not been saved to the API.
*/
- (BOOL)isUnsynced;

/**
 @return Call -isDataAvailable to determine if the model has been loaded completely. In some
 cases, the Inbox API returns model instances which only have an ID and namespaceID, for example,
 when you ask for an INMessage that is not available in the local cache. To fully load the model,
 call -reload:.
*/
- (BOOL)isDataAvailable;

/**
@return The namespace this model is associated with.
*/
- (INNamespace*)namespace;

/** @name Resource Representation */

/**
 Uses the resourceMapping mapping and the object's property values
 to create a JSON-compatible NSDictionary.

 @return An NSDictionary of JSON-compatible key-value pairs.
*/
- (NSMutableDictionary *)resourceDictionary;

/**
 @param dict A JSON dictionary with one or more key-value pairs matching the ones
 declared in resourceMapping.
 @return YES if the resource dictionary represents a change to the model.
 */
- (BOOL)differentFromResourceDictionary:(NSDictionary *)dict;

/**
 Applies the JSON to the object, overriding existing property values when key-value
 pairs are present in the json.

 @param dict A JSON dictionary with one or more key-value pairs matching the ones
 declared in resourceMapping.
*/
- (void)updateWithResourceDictionary:(NSDictionary *)dict;


/** @name Resource Loading and Saving */

/**
 Reload the model by perfoming a GET request to the APIPath.

 @param callback An optional callback that allows you to capture errors and present
 alerts that the user may expect when a reload fails.
 */
- (void)reload:(ErrorBlock)callback;



/** @name Override Points & Subclassing Support */

/**
 Subclasses override resourceMapping to define the mapping between their
 Objective-C @property's and the key-value pairs in their JSON representations. Providing
 this mapping allows -initWithResourceDictionary: and -resourceDictionary to convert the instance
 into JSON without additional glue code.

 A typical subclass implementation looks like this:

     + (NSMutableDictionary *)resourceMapping
     {
        NSMutableDictionary * mapping = [super resourceMapping];
        [mapping addEntriesFromDictionary: @{
           @"firstName": @"first_name",
           @"lastName": @"last_name",
           @"email": @"email"
        }];
        return mapping;
     }

 @return A dictionary mapping iOS property names to JSON fields.
 */
+ (NSMutableDictionary *)resourceMapping;

/**
 @return The name of this class (i.e. "namespaces") for use in API URLs.
 */
+ (NSString *)resourceAPIName;

/**
@return The URL path to this object.
*/
- (NSString *)resourceAPIPath;

/**
 @return The table that should be used to cache this model in local storage.
 */
+ (NSString *)databaseTableName;

/**
 @return An array of property names other than ID and namespaceID that should be
 queryable. It's important to return all of the properties you may want to use in
 predicates and sort descriptors.
 */
+ (NSArray *)databaseIndexProperties;

/**
 @return An array of NSArray properties that should use separate tables to enable
 indexing in a one-to-many fashion.
*/
+ (NSArray *)databaseJoinTableProperties;

/**
 Setup should be overridden in subclasses to perform additional initialization
 that needs to take place after -initWithCoder: or -initWithResourceDictionary: The base class
 implementation does nothing.
 */
- (void)setup;

/** 
 May be implemented by subclasses to perform additional setup after the main database table
 for caching the class has been initialized and indexes have been created.
 
 The default implementation of this method does nothing.
 
 @param db An FMDatabase for performing additional queries.
 */
+ (void)afterDatabaseSetup:(FMDatabase*)db;

/**
 May be implemented to perform additional work before the instance is saved to the local cache.

@param db An FMDatabase for performing additional queries.
*/
- (void)beforePersist:(FMDatabase*)db;

/**
 May be implemented to perform additional work after the instance is saved to the local cache.
 
 @param db An FMDatabase for performing additional queries.
 */
- (void)afterPersist:(FMDatabase*)db;

/**
 May be implemented to perform additional work before the instance is removed from the local cache.
 
 @param db An FMDatabase for performing additional queries.
 */
- (void)beforeUnpersist:(FMDatabase*)db;

/**
 May be implemented to perform additional work after the instance is removed from the local cache.
 
 @param db An FMDatabase for performing additional queries.
 */
- (void)afterUnpersist:(FMDatabase*)db;

@end
