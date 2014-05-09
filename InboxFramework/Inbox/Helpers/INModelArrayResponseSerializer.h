//
//  INModelArrayResponseSerializer.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

/**
 A subclass of AFJSONResponseSerializer that automatically parses Inbox API 
 responses and saves the returned INModelObjects to the local data store.
 
 Any models that are already in memory are updated. This causes
 INModelObjectChangedNotifications so changes propogate to views and controllers
 listening on these models.
*/

@interface INModelArrayResponseSerializer : AFJSONResponseSerializer

@property (nonatomic, strong) Class modelClass;

- (id)initWithModelClass:(Class)klass;

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError * __autoreleasing *)error;

@end
