//
//  INModelView.h
//  BigSur
//
//  Created by Ben Gotow on 4/24/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

@interface INModelProvider (Private)

- (NSPredicate*)fetchPredicate;
- (void)fetchFromCache;
- (void)fetchFromAPI;
- (NSDictionary *)queryParamsForPredicate:(NSPredicate*)predicate;

#pragma mark Receiving Updates from the Database;

- (void)managerDidPersistModels:(NSArray *)savedArray;
- (void)managerDidUnpersistModels:(NSArray*)models;
- (void)managerDidReset;

@end