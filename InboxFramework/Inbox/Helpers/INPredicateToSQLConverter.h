//
//  INPredicateConverter.h
//  BigSur
//
//  Created by Ben Gotow on 4/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface INPredicateToSQLConverter : NSObject

@property (nonatomic, strong) Class targetModelClass;

- (NSString *)SQLFilterForPredicate:(NSPredicate *)predicate;
- (NSString *)SQLSortForSortDescriptor:(NSSortDescriptor *)descriptor;

@end
