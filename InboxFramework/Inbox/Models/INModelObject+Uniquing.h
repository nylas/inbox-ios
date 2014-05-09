//
//  INModelObject+Uniquing.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"

@interface INModelObject (Uniquing)

/** @name Globally Unique Instances */

/**
 Returns the model object with the given ID currently in memory, if one exists.
 If one does not exist and the 'shouldCreate' option is provided, it is created
 and attached to the instance table. If you intend to create the model, you should
 allow this method to do it while locking the instance lookup table to prevent
 threading issues that could result in two copies of the model in memory.
 
 The primary purpose of this method is to retrieve an instance of an object so
 you can avoid allocating a new one, and avoid scenarios where multiple copies of
 a single logical object are floating around, which may be out of sync with each 
 other and the local datastore.
 
 @param ID The ID of the object you're looking for.
 
 @param shouldCreate YES if you intend to create this model. You should always let
 ths method create the object for you and lock while it attaches it to the instance table.
 
 @param didCreate A BOOL, passed by reference, indicating whether the model returned
 was just created.
 
 @return An instance, or nil.
 */
+ (id)attachedInstanceMatchingID:(id)ID createIfNecessary:(BOOL)shouldCreate didCreate:(BOOL*)didCreate;

/**
 Locks the instance table and attaches the provided model. This method throws an 
 exception if another model of the same class is already in the instance table 
 with the same ID.
*/
+ (void)attachInstance:(INModelObject *)obj;

/**
 @return A copy of the INModelObject that is not attached to the instance table. 
 This is useful if you want to clone an object to modify it and keep two versions alive.
*/
- (id)detatchedCopy;

/**
 @return YES, if this object has not been attached to the instance tree and is not the
 official version of the object.
*/
- (BOOL)isDetatched;

@end
