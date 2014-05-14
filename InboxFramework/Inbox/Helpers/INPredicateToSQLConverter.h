//
//  INPredicateConverter.h
//  BigSur
//
//  Created by Ben Gotow on 4/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface INPredicateToSQLConverter : NSObject

@property (nonatomic, strong) Class modelClass;
@property (nonatomic, strong) NSMutableArray * additionalJoins;
@property (nonatomic, strong) NSMutableArray * additionalJoinRHSExpressions;

+ (INPredicateToSQLConverter*)converterForModelClass:(Class)modelClass;

- (NSString *)SQLForPredicate:(NSPredicate*)predicate;
- (NSString *)SQLForSortDescriptors:(NSArray*)descriptors;

@end
