//
//  INPredicateConverter.m
//  BigSur
//
//  Created by Ben Gotow on 4/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INPredicateToSQLConverter.h"
#import "INModelObject.h"

#define NSF(x...) [NSString stringWithFormat: x]

static NSString * SQLNullValueString = @"NULL";


@implementation INPredicateToSQLConverter

+ (INPredicateToSQLConverter*)converterForModelClass:(Class)modelClass
{
	INPredicateToSQLConverter * converter = [[INPredicateToSQLConverter alloc] init];
	[converter setModelClass: modelClass];
	return converter;
}

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
			retStr = NSF(@"%@(%@)", convertibleSetOperations[setOpt], clean);
		}

	if (retStr != nil) return retStr;

	return keyPath;
}

- (NSString *)SQLSelectClauseForSubqueryExpression:(NSExpression *)expression
{
	NSAssert(false, @"SQLSelectClauseForSubqueryExpression not implemented");
	return nil;
}

- (NSString *)SQLLiteralListForArray:(NSArray *)array
{
	NSMutableArray * retArray = [NSMutableArray array];

	for (NSExpression * obj in array)
		[retArray addObject:[self SQLExpressionForNSExpression:obj]];

	return NSF(@"(%@)", [retArray componentsJoinedByString:@","]);
}

- (NSString *)SQLFunctionLiteralForFunctionExpression:(NSExpression *)exp
{
	NSDictionary * nullaryFunctions = @{@"now" : @"date('now')", @"random" : @"random()"};
	NSDictionary * unaryFunctions = @{@"uppercase:" : @"upper", @"lowercase:" : @"lower", @"abs:" : @"abs"};
	NSDictionary * binaryFunctions = @{@"add:to:": @"+", @"from:subtract:" : @"-", @"multiply:by:" : @"*", @"divide:by:" : @"/", @"modulus:by:": @"%", @"leftshift:by" : @"<<", @"rightshift:by:" : @">>"};

	if ([[nullaryFunctions allKeys] containsObject:[exp function]]) {
		return nullaryFunctions[[exp function]];
	
	} else if ([[unaryFunctions allKeys] containsObject:[exp function]]) {
		return NSF(@"%@(%@)", unaryFunctions[[exp function]], [self SQLExpressionForNSExpression:[exp arguments][0]]);
	
	} else if ([[binaryFunctions allKeys] containsObject:[exp function]]) {
		return NSF(@"(%@ %@ %@)", [self SQLExpressionForNSExpression:[exp arguments][0]], binaryFunctions[[exp function]], [self SQLExpressionForNSExpression:[exp arguments][1]]);
	
	} else {
		NSLog(@"SQLFunctionLiteralForFunctionExpression could not be converted because it uses an unconvertible function");
	}
	return nil;
}

- (NSString *)SQLNamedReplacementVariableForVariable:(NSString *)var
{
	return var;
}

- (NSString *)SQLConstantForValue:(id)val
{
	if (val == nil)
		return SQLNullValueString;

	if ([val isEqual:[NSNull null]])
		return SQLNullValueString;

	if ([val isKindOfClass:[NSString class]])
		return val;

	if ([val respondsToSelector:@selector(intValue)])
		return [val stringValue];

	return [self SQLConstantForValue:[val description]];
}

- (NSString *)SQLExpressionForNSExpression:(NSExpression *)expression
{
	NSString * retStr = nil;

	switch ([expression expressionType]) {
		case NSConstantValueExpressionType:
			 retStr = [self SQLConstantForValue:[expression constantValue]];
			 break;

		case NSVariableExpressionType:
			 retStr = [self SQLNamedReplacementVariableForVariable:[expression variable]];
			 break;

		case NSKeyPathExpressionType:
			 retStr = [self SQLExpressionForKeyPath:[expression keyPath]];
			 break;

		case NSFunctionExpressionType:
			 retStr = [self SQLFunctionLiteralForFunctionExpression:expression];
			 break;

		case NSSubqueryExpressionType:
			 retStr = [self SQLSelectClauseForSubqueryExpression:expression];
			 break;

		case NSAggregateExpressionType:
			 retStr = [self SQLLiteralListForArray:[expression collection]];
			 break;

		case NSUnionSetExpressionType:
		case NSIntersectSetExpressionType:
		case NSMinusSetExpressionType:
		case NSEvaluatedObjectExpressionType:
		case NSAnyKeyExpressionType:
		case NSBlockExpressionType:
			break;
	}
	return retStr;
}

- (NSString *)SQLColumnForPropertyName:(NSString *)propertyName
{
	// check to make sure this column is allowed. You can only query against columns
	// listed in the databaseIndexProperties.
	if ([[_modelClass databaseIndexProperties] containsObject:propertyName])
		return [[_modelClass resourceMapping] objectForKey:propertyName];
	
	if ([[_modelClass databaseJoinTableProperties] containsObject: propertyName])
		return propertyName;
	
	NSAssert(false, @"Sorry, this class can only be queried by %@ and %@. There is no index on %@!", [_modelClass databaseIndexProperties], [_modelClass databaseJoinTableProperties], propertyName);
	return nil;
}

- (NSString *)SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate
{
	NSString * leftPropertyName = [self SQLConstantForValue:[[predicate leftExpression] keyPath]];
	NSString * rightSQLExpression = [self SQLExpressionForNSExpression:[predicate rightExpression]];
	NSString * leftSQLExpression = nil;
	
	if ([[_modelClass databaseJoinTableProperties] containsObject: leftPropertyName]) {
		if (!_additionalJoins) {
			_additionalJoins = [NSMutableArray array];
            _additionalJoinRHSExpressions = [NSMutableArray array];
        }
        
        // are we already doing a JOIN scan for this value? Don't do it again! These
        // are hugely expensive. No more WHERE unread AND unread.
        if ([_additionalJoinRHSExpressions containsObject: rightSQLExpression])
            return @"1 = 1";
        
		NSString * as = NSF(@"T%d", (int)[_additionalJoins count]);
		NSString * joinTable = NSF(@"%@-%@", [_modelClass databaseTableName], leftPropertyName);
		NSString * joinSQL = NSF(@"INNER JOIN '%@' as '%@' ON '%@'.id = '%@'.id", joinTable, as, as, [_modelClass databaseTableName]);
		[_additionalJoins addObject: joinSQL];
		[_additionalJoinRHSExpressions addObject: rightSQLExpression];
        
		leftSQLExpression = NSF(@"'%@'.value", as);
	} else {
		leftSQLExpression = [self SQLColumnForPropertyName: leftPropertyName];
	}
	

	switch ([predicate predicateOperatorType]) {
		case NSLessThanPredicateOperatorType:
			return NSF(@"(%@ < '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSLessThanOrEqualToPredicateOperatorType:
			return NSF(@"(%@ <= '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSGreaterThanPredicateOperatorType:
			return NSF(@"(%@ > '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSGreaterThanOrEqualToPredicateOperatorType:
			return NSF(@"(%@ >= '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSEqualToPredicateOperatorType:
			return NSF(@"(%@ = '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSNotEqualToPredicateOperatorType:
			return NSF(@"(%@ <> '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSMatchesPredicateOperatorType:
			return NSF(@"(%@ MATCH '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSInPredicateOperatorType:
			return NSF(@"(%@ IN '%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSBetweenPredicateOperatorType:
			return NSF(@"(%@ BETWEEN '%@' AND '%@')", leftSQLExpression,
				   [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][0]],
				   [self SQLExpressionForNSExpression:[[predicate rightExpression] collection][1]]);
			break;

		case NSLikePredicateOperatorType:
		case NSContainsPredicateOperatorType:
			return NSF(@"(%@ LIKE '%%%@%%')", leftSQLExpression, rightSQLExpression);
			break;

		case NSBeginsWithPredicateOperatorType:
			return NSF(@"(%@ LIKE '%@%%')", leftSQLExpression, rightSQLExpression);
			break;

		case NSEndsWithPredicateOperatorType:
			return NSF(@"(%@ LIKE '%%%@')", leftSQLExpression, rightSQLExpression);
			break;

		case NSCustomSelectorPredicateOperatorType:
			NSLog(@"SQLWhereClauseForComparisonPredicate custom selectors are not supported");
			break;
	}

	return nil;
}


- (NSString *)SQLWhereClauseForPredicate:(NSPredicate *)predicate
{
	if ([predicate respondsToSelector:@selector(compoundPredicateType)])
		return [self SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate];
	
	if ([predicate respondsToSelector:@selector(predicateOperatorType)])
		return [self SQLWhereClauseForComparisonPredicate:(NSComparisonPredicate *)predicate];
	
	NSAssert(false, @"SQLFilterForPredicate predicate is not of a convertible class");
	return nil;
}

- (NSString *)SQLWhereClauseForCompoundPredicate:(NSCompoundPredicate *)predicate
{
	NSMutableArray * subs = [NSMutableArray array];
	for (NSPredicate * sub in [predicate subpredicates])
		[subs addObject:[self SQLWhereClauseForPredicate:sub]];

	NSString * conjunction = nil;
	switch ([(NSCompoundPredicate *)predicate compoundPredicateType]) {
		case NSAndPredicateType:
			conjunction = @" AND ";
			break;

		case NSOrPredicateType:
			conjunction = @" OR ";
			break;

		case NSNotPredicateType:
			conjunction = @" NOT ";
			break;

		default:
			conjunction = @" ";
			break;
	}

	return NSF(@"(%@)", [subs componentsJoinedByString:conjunction]);
}

- (NSString *)SQLForSortDescriptors:(NSArray*)descriptors
{
	NSMutableArray * sortClauses = [NSMutableArray array];

	for (NSSortDescriptor * descriptor in descriptors) {
		NSString * databaseKey = [self SQLColumnForPropertyName:[descriptor key]];
		NSString * databaseOrder = [descriptor ascending] ? @"ASC" : @"DESC";
		NSString * sql = NSF(@"%@ %@", databaseKey, databaseOrder);
		if (sql) [sortClauses addObject:sql];
	}
	return NSF( @" ORDER BY %@", [sortClauses componentsJoinedByString:@", "]);
}

- (NSString*)SQLForPredicate:(NSPredicate *)predicate
{
	// Use our helper to assemble the WHERE clause. It's important that we group the results, because the
	// inner joins often result in multiple rows per matching object.
	NSString * where = [self SQLWhereClauseForPredicate:predicate];
	NSString * joins = [_additionalJoins componentsJoinedByString: @" "];
	if (joins == nil) joins = @"";
	
	return NSF(@" %@ WHERE %@ GROUP BY %@.`id`", joins, where, [_modelClass databaseTableName]);
}

@end
