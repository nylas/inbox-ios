//
//  INPredicateToQueryParamConverter.h
//  BigSur
//
//  Created by Ben Gotow on 5/2/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface INPredicateToQueryParamConverter : NSObject

@property (nonatomic, strong) NSDictionary * keysToParamsTable;
@property (nonatomic, strong) NSDictionary * keysToLIKEParamsTable;

- (NSDictionary*)paramsForPredicate:(NSPredicate*)predicate;

@end
