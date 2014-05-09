//
//  INPredicateToQueryParamConverter.m
//  BigSur
//
//  Created by Ben Gotow on 5/2/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INPredicateToQueryParamConverter.h"

@implementation INPredicateToQueryParamConverter

- (NSDictionary*)paramsForPredicate:(NSPredicate*)predicate
{
	NSMutableDictionary * params = [NSMutableDictionary dictionary];
	
	if ([predicate isKindOfClass: [NSCompoundPredicate class]]) {
		if ([(NSCompoundPredicate*)predicate compoundPredicateType] != NSAndPredicateType)
			NSAssert(false, @"Only AND predicates are currently supported in constructing queries.");
		
		for (NSPredicate * subpredicate in [(NSCompoundPredicate*)predicate subpredicates])
			[params addEntriesFromDictionary: [self paramsForPredicate: subpredicate]];
		
	} else if ([predicate isKindOfClass: [NSComparisonPredicate class]]) {
		NSComparisonPredicate * pred = (NSComparisonPredicate*)predicate;
		if ([[pred rightExpression] expressionType] != NSConstantValueExpressionType)
			NSAssert(false, @"Only constant values can be on the RHS of predicates.");
		if ([[pred leftExpression] expressionType] != NSKeyPathExpressionType)
			NSAssert(false, @"Only property names can be on the LHS of predicates.");
		
		
		NSString * keyPath = [[pred leftExpression] keyPath];
		NSString * rhs = [[pred rightExpression] constantValue];
		
		if (_keysToParamsTable[keyPath]) {
			NSAssert([pred predicateOperatorType] == NSEqualToPredicateOperatorType, @"Sorry, predicates for %@ can only use the '=' operator.", keyPath);
			NSString * param = _keysToParamsTable[keyPath];
			[params setObject:rhs forKey:param];
		}
		
		if (_keysToLIKEParamsTable[keyPath]) {
			NSString * param = _keysToLIKEParamsTable[keyPath];
			[params setObject:rhs forKey:param];
		}
	}
	
	return params;
}
@end
