//
//  INModelObject.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INAPIManager.h"

@class INAPIOperation;

static NSString * INModelObjectChangedNotification = @"model_changed";

/**
 INModelObject is the base class for model objects in the Inbox framework. It provides
 core functionality related to object serialization and is intended to be subclassed.
*/
@interface INModelObject : NSObject <NSCoding>
{
	NSDictionary * _precommitResourceDictionary;
}

@property (nonatomic, strong) NSString * ID;
@property (nonatomic, strong) NSString * namespaceID;
@property (nonatomic, strong) NSDate * createdAt;
@property (nonatomic, strong) NSDate * updatedAt;


#pragma Getting Instances

/** @name Retrieving Instances */

/**
 @return An instance of the requested class. If a copy of this model is already in memory, this
 method returns the same instance. If it has been stored in the Inbox local cache, it will be
 retrieved from cache. If no copy of the object is available, an empty instance is returned.
 Subscribe to this instance to be notified when it's data becomes available and update your
 UI accordingly. */
+ (id)instanceWithID:(NSString*)ID;


/** @name Resource Representation */

/**
 Uses the resourceMapping mapping and the object's property values
 to create a JSON-compatible NSDictionary.

 @return An NSDictionary of JSON-compatible key-value pairs.
*/
- (NSMutableDictionary *)resourceDictionary;

/**
 @return YES if the resource dictionary represents a change to the model.
 */
- (BOOL)differentFromResourceDictionary:(NSDictionary *)dict;

/**
 Applies the JSON to the object, overriding existing property values when key-value
 pairs are present in the json.

 @param json A JSON dictionary with one or more key-value pairs matching the ones
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

/**
 Open an update block for saving changes to the object. Changes made to models should
 always be done within an update block so that changes rejected upstream can be properly
 restored.
 */
- (void)beginUpdates;

/**
 Commit a set of changes to the object's properties and initiates an API call to
 save the changes.
 */
- (INAPIOperation *)commitUpdates;

/**
 Save the model to the server. This method may be overriden in subclasses. The
 default implementation does a PUT to the APIPath for objects with IDs, and a POST
 to the APIPath (without an ID) for new objects.

 Note that -save is eventually persistent. The save operation may be held in queue
 until network connectivity is available.

 @return An INAPIOperation that you can use to track the progress of the save operation.
 INAPIOperation's are a subclass of AFHTTPRequestOperation, so you can add completion 
 blocks, etc.
 */
- (INAPIOperation *)save;

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
 Setup should be overridden in subclasses to perform additional initialization
 that needs to take place after -initWithCoder: or -initWithResourceDictionary: The base class
 implementation does nothing.
 */
- (void)setup;

@end
