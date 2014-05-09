//
//  INPredicateConverter.m
//  BigSur
//
//  Created by Ben Gotow on 4/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INPredicateToSQLConverter.h"
#import "INModelObject.h"

static NSString * SQLNullValueString = @"NULL";

@implementation INPredicateToSQLConverter

- (NSString *)SQLExpressionForKeyPath:(NSString *)keyPath
{
	NSString * retStr = nil;
	NSDictionary * convertibleSetOperations = @{
		@"@avg" : @"avg",
		@"@max" : @"max",
		@"@min" : @"min",
		@"@sum" : @"sum",
		@"@distinctUnionOfObjects" : @"distinct"
	};

	for (NSString * setOpt in [convertibleSetOperations allKeys])
		if ([keyPath hasSuffix:setOpt]) {
			NSString * clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
			retStr = [NSString stringWithFormat:@"%@(%@)", convertibleSetOperations[setOpt], clean];
		}

	if (retStr != nil) return retStr;

	return keyPath;
}

- (NSString *)SQLSelectClauseForSubqueryExpression:(NSExpression *)expression
{
	NSLog(@"SQLSelectClauseForSubqueryExpression not implemented");
	return nil;
}

- (NSString *)SQLLiteralListForArray:(NSArray *)array
{
	NSMutableArray * retArray = [NSMutableArray array];

	for (NSExpression * obj in array)
		[retArray addObject:[self SQLExpressionForNSExpression:obj]];

	return [NSString stringWithFormat:@"(%@)", [retArray componentsJoinedByString:@","]];
}

- (NSString *)SQLFunctionLiteralForFunctionExpression:(NSExpression *)exp
{
	NSDictionary * convertibleNullaryFunctions = @{@"now" : @"date('now')", @"random" : @"random()"};
	NSDictionary * convertibleUnaryFunctions = @{@"uppercase:" : @"upper", @"lowercase:" : @"lower", @"abs:" : @"abs"};
	NSDictionary * convertibleBinaryFunctions = @{@"add:to:": @"+", @"from:subtract:" : @"-", @"multiply:by:" : @"*", @"divide:by:" : @"/", @"modulus:by:": @"%", @"leftshift:by" : @"<<", @"rightshift:by:" : @">>"};

	if ([[convertibleNullaryFunctions allKeys] containsObject:[exp function]]) {
		return convertibleNullaryFunctions[[exp function]];
	}
	else {
		if ([[convertibleUnaryFunctions allKeys] containsObject:[exp function]]) {
			return [NSString stringWithFormat:@"%@(%@)", convertibleUnaryFunctions[[exp function]], [self SQLExpressionForNSExpression:[exp arguments][0]]];
		}
		else {
			if ([[convertibleBinaryFunctions allKeys] containsObject:[exp function]])
				return [NSString stringWithFormat:@"(%@ %@ %@)", [self SQLExpressionForNSExpression:[exp arguments][0]], convertibleBinaryFunctions[[exp function]], [self SQLExpressionForNSExpression:[exp arguments][1]]];
			else
				NSLog(@"SQLFunctionLiteralForFunctionExpression could not be converted because it uses an unconvertible function");
		}
	}
	return nil;
}

- (NSString *)SQLNamedReplacementVariableForVariable:(NSString *)var
{
	return var;
}

- (NSString *)SQLFilterForPredicate:(NSPredicate *)predicate
{
	if ([predicate respondsToSelector:@selector(compoundPredicateType)]) {
		return [self SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate];
	}
	else {
		if ([predicate respondsToSelector:@selector(predicateOperatorType)])
			return [self SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate];
		else
			NSLog(@"SQLFilterForPredicate predicate is not of a convertible class");
	}
	return nil;
}

- (NSString *)SQLColumnForPropertyName:(NSString *)propertyName
{
	if (_targetModelClass) {
		// check to make sure this column is allowed. You can only query against columns
		// listed in the databaseIndexProperties.
		NSString * key = [[_targetModelClass resourceMapping] objectForKey:propertyName];
		NSArray * allowedPropertyNames = [@[@"ID"] arrayByAddingObjectsFromArray :[_targetModelClass databaseIndexProperties]];
		if (![allowedPropertyNames containsObject:propertyName])
			NSAssert(false, @"Sorry, this class can only be queried by %@. There is no index on %@!", allowedPropertyNames, propertyName);

		return key;
	
	} else {
		return propertyName;
	}
}

- (NSString *)SQLExpressionForLeftKeyPath:(NSString *)keyPath
{
	NSString * retStr = nil;
	NSDictionary * convertibleSetOperations = @{@"@avg" : @"avg", @"@max" : @"max", @"@min" : @"min", @"@sum" : @"sum", @"@distinctUnionOfObjects" : @"distinct"};

	for (NSString * setOpt in [convertibleSetOperations allKeys])
		if ([keyPath hasSuffix:setOpt]) {
			NSString * clean = [[keyPath stringByReplacingOccurrencesOfString:setOpt withString:@""] stringByReplacingOccurrencesOfString:@".." withString:@"."];
			retStr = [NSString stringWithFormat:@"%@(%@)", convertibleSetOperations[setOpt], clean];
		}

	if (retStr != nil) return [self SQLColumnForPropertyName:retStr];

	return [self SQLColumnForPropertyName:keyPath];
}

- (NSString *)SQLConstantForLeftValue:(id)val
{
	if (val == nil) return SQLNullValueString;

	if ([val isEqual:[NSNull null]]) return SQLNullValueString;

	if ([val isKindOfClass:[NSString class]]) {
		return [self SQLColumnForPropertyName:val];
	}
	else {
		if ([val respondsToSelector:@selector(intValue)])
			return [self SQLColumnForPropertyName:[val stringValue]];
		else
			return [self SQLConstantForLeftValue:[val description]];
	}
	return nil;
}

- (NSString *)SQLExpressionForLeftNSExpression:(NSExpression *)expression
{
	NSString * retStr = nil;

	switch ([expression expressionType]) {
		case NSConstantValueExpressionType:
			{retStr = [self SQLConstantForLeftValue:[expression constantValue]];
			// NSLog(@"LEFT  NSConstantValueExpressionType %@",retStr); // contains 'Patient Name' etc..
			 break; }

		case NSVariableExpressionType:
			{retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
			// NSLog(@"LEFT NSVariableExpressionType %@",retStr);
			 break; }

		case NSKeyPathExpressionType:
			{retStr = [self SQLExpressionForLeftKeyPath:[expression keyPath]];
			// NSLog(@"LEFT NSKeyPathExpressionType %@",retStr); // first "Patient Name'
			 break; }

		case NSFunctionExpressionType:
			{retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
			// NSLog(@"LEFT NSFunctionExpressionType %@",retStr);
			 break; }

		case NSSubqueryExpressionType:
			{retStr = [self SQLSelectClauseForSubqueryExpression:expression];
			// NSLog(@"LEFT NSSubqueryExpressionType %@",retStr);
			 break; }

		case NSAggregateExpressionType:
			{retStr = [self SQLLiteralListForArray:[expression collection]];
			// NSLog(@"LEFT NSAggregateExpressionType %@",retStr);
			 break; }

		case NSUnionSetExpressionType:
			{break; }

		case NSIntersectSetExpressionType:
			{break; }

		case NSMinusSetExpressionType:
			{break; }

		case NSEvaluatedObjectExpressionType:
			{break; }	// these can't be converted

		case NSAnyKeyExpressionType:
		case NSBlockExpressionType:
			{break; }
			// case NSAnyKeyExpressionType: { break; }
	}
	return retStr;
}

- (NSString *)SQLConstantForValue:(id)val
{
	if (val == nil) return SQLNullValueString;

	if ([val isEqual:[NSNull null]]) return SQLNullValueString;

	if ([val isKindOfClass:[NSString class]]) {
		return val;
	}
	else {
		if ([val respondsToSelector:@selector(intValue)])
			return [val stringValue];
		else
			return [self SQLConstantForValue:[val description]];
	}
	return nil;
}

- (NSString *)SQLExpressionForNSExpression:(NSExpression *)expression
{
	NSString * retStr = nil;

	switch ([expression expressionType]) {
		case NSConstantValueExpressionType:
			{retStr = [self SQLConstantForValue:[expression constantValue]];
			// NSLog(@"NSConstantValueExpressionType %@",retStr); // contains 'Patient Name' etc..
			 break; }

		case NSVariableExpressionType:
			{retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
			// NSLog(@"NSVariableExpressionType %@",retStr);
			 break; }

		case NSKeyPathExpressionType:
			{retStr = [self SQLExpressionForKeyPath:[expression keyPath]];
			// NSLog(@"NSKeyPathExpressionType %@",retStr);
			 break; }

		case NSFunctionExpressionType:
			{retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
			// NSLog(@"NSFunctionExpressionType %@",retStr);
			 break; }

		case NSSubqueryExpressionType:
			{retStr = [self SQLSelectClauseForSubqueryExpression:expression];
			// NSLog(@"NSSubqueryExpressionType %@",retStr);
			 break; }

		case NSAggregateExpressionType:
			{retStr = [self SQLLiteralListForArray:[expression collection]];
			// PSLog(@"NSAggregateExpressionType %@",retStr);
			 break; }

		case NSUnionSetExpressionType:
			{break; }

		case NSIntersectSetExpressionType:
			{break; }

		case NSMinusSetExpressionType:
			{break; }

		case NSEvaluatedObjectExpressionType:
			{break; }	// these can't be converted

		case NSAnyKeyExpressionType:
		case NSBlockExpressionType:
			{break; }
			// case NSAnyKeyExpressionType: { break; }
	}
	return retStr;
}

- (NSString *)SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate
{
	NSString * leftSQLExpression = [self SQLExpressionForLeftNSExpression:[predicate leftExpression]];
	NSString * rightSQLExpression = [self SQLExpressionForNSExpression:[predicate rightExpression]];

	switch ([predicate predicateOperatorType]) {
		case NSLessThanPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ < '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSLessThanOrEqualToPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ <= '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSGreaterThanPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ > '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSGreaterThanOrEqualToPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ >= '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSEqualToPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ = '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSNotEqualToPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ <> '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSMatchesPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ MATCH '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSInPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ IN '%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSBetweenPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ BETWEEN '%@' AND '%@')", [self SQLExpressionForLeftNSExpression:[predicate leftExpression]],
					   [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][0]],
					   [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][1]]];

				break;
			}

		case NSLikePredicateOperatorType:
		case NSContainsPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ LIKE '%%%@%%')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSBeginsWithPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ LIKE '%@%%')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSEndsWithPredicateOperatorType:
			{
				return [NSString stringWithFormat:@"(%@ LIKE '%%%@')", leftSQLExpression, rightSQLExpression];

				break;
			}

		case NSCustomSelectorPredicateOperatorType:
			{
				NSLog(@"SQLWhereClauseForComparisonPredicate custom selectors are not supported");
				break;
			}
	}

	return nil;
}

- (NSString *)SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate
{
	NSMutableArray * subs = [NSMutableArray array];

	for (NSPredicate * sub in [predicate subpredicates]) [subs addObject:[self SQLFilterForPredicate:sub]];

	;

	NSString * conjunction;
	switch ([(NSCompoundPredicate *)predicate compoundPredicateType]) {
		case NSAndPredicateType:
			{conjunction = @" AND "; break; }

		case NSOrPredicateType:
			{conjunction = @" OR "; break; }

		case NSNotPredicateType:
			{conjunction = @" NOT "; break; }

		default:
			{conjunction = @" "; break; }
	}

	return [NSString stringWithFormat:@"(%@)", [subs componentsJoinedByString:conjunction]];
}

- (NSString *)SQLSortForSortDescriptor:(NSSortDescriptor *)descriptor
{
	NSString * databaseKey = [self SQLColumnForPropertyName:[descriptor key]];
	NSString * databaseOrder = [descriptor ascending] ? @"ASC" : @"DESC";

	return [NSString stringWithFormat:@"%@ %@", databaseKey, databaseOrder];
}

@end
