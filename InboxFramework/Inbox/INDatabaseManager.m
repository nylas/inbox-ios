//
//  INDatabaseManager.m
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INDatabaseManager.h"
#import "INPredicateToSQLConverter.h"
#import "FMResultSet+INModelQueries.h"
#import "NSObject+Properties.h"

#define SCHEMA_VERSION 2
#define DATABASE_PATH [@"~/Documents/cache.db" stringByExpandingTildeInPath]

__attribute__((constructor))
static void initialize_INDatabaseManager() {
    [INDatabaseManager shared];
}


@implementation INDatabaseManager

+ (INDatabaseManager *)shared
{
	static INDatabaseManager * sharedManager = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedManager = [[INDatabaseManager alloc] init];
	});
	return sharedManager;
}

- (id)init
{
	self = [super init];

	if (self) {
		NSLog(@"%@ SQLite v. %s", DATABASE_PATH, sqlite3_version);
		
		_queue = [FMDatabaseQueue databaseQueueWithPath: DATABASE_PATH];
		_queryDispatchQueue = dispatch_queue_create("INDatabaseManager Queue", DISPATCH_QUEUE_CONCURRENT);
		_observers = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:10];
		_initializedModelClasses = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)resetDatabase
{
	NSLog(@"Resetting the local datastore.");
	
	[_initializedModelClasses removeAllObjects];
	[_queue close];
	_queue = nil;
	
	[[NSFileManager defaultManager] removeItemAtPath:DATABASE_PATH error:nil];
	_queue = [FMDatabaseQueue databaseQueueWithPath:DATABASE_PATH];

	dispatch_async(dispatch_get_main_queue(), ^{
		// notify all our observers of a total reset
		[[_observers setRepresentation] makeObjectsPerformSelector:@selector(managerDidReset)];
	});
}

- (int)databaseSchemaVersion
{
	int __block version = -1;

	[_queue inDatabase:^(FMDatabase * db) {
		FMResultSet * set = [db executeQuery:@"PRAGMA user_version"];
		[set next];
		version = [[[set resultDictionary] objectForKey:@"user_version"] intValue];
		[set close];
	}];

	return version;
}

- (BOOL)executeSQLFileWithName:(NSString *)sqlFileName
{
	BOOL __block succeeded = NO;

	[_queue inTransaction:^(FMDatabase * db, BOOL * rollback) {
		NSError * error = nil;
		NSString * batchSQLPath = [[NSBundle mainBundle] pathForResource:sqlFileName ofType:@"sql"];
		NSString * batchSQL = [NSString stringWithContentsOfFile:batchSQLPath encoding:NSUTF8StringEncoding error:&error];

		if (error || ![batchSQL length]) {
			NSLog(@"Batch SQL run failed because sql could not be found for %@. %@", sqlFileName, [error localizedDescription]);
			*rollback = YES;
		}

		NSArray * statements = [batchSQL componentsSeparatedByString:@"\n\n"];

		for (NSString * statement in statements) {
			BOOL success = [db executeUpdate:statement];

			if (!success)
				break;
		}

		if ([db hadError]) {
			NSLog(@"Batch SQL failed with error: %@", [db lastErrorMessage]);
			*rollback = YES;
		}
		else {
			NSLog(@"Batch SQL %@ complete. Executed %lu statements.", sqlFileName, (unsigned long)[statements count]);
			*rollback = NO;
			succeeded = YES;
		}
	}];

	return succeeded;
}

- (void)registerCacheObserver:(NSObject <INDatabaseObserver> *)observer
{
	[_observers addObject:observer];
}

- (BOOL)checkModelTable:(Class)klass
{
	if (klass == NULL)
		return NO;
		
	NSAssert([klass isSubclassOfClass:[INModelObject class]], @"Only subclasses of INModelObject can be cached.");

	if (!_initializedModelClasses[[klass databaseTableName]]) {
		[_initializedModelClasses setObject:@(YES) forKey:[klass databaseTableName]];
		
		BOOL __block succeeded = YES;
		[_queue inTransaction:^(FMDatabase * db, BOOL * rollback) {
			[self initializeModelTable:klass inDatabase:db];
			[self initializeModelJOINTables:klass inDatabase: db];
			if ([klass resolveClassMethod: @selector(afterDatabaseSetup:)])
				[klass afterDatabaseSetup: db];
			
			if ([db hadError]) {
				*rollback = YES;
				succeeded = NO;
			}
		}];
		return succeeded;
	}
	return YES;
}

- (void)initializeModelTable:(Class)klass inDatabase:(FMDatabase*)db
{
	NSMutableArray * cols = [@[@"id TEXT PRIMARY KEY", @"data BLOB"] mutableCopy];
	NSMutableArray * colIndexSQLs = [NSMutableArray array];
	NSString * tableName = [klass databaseTableName];

	for (NSString * propertyName in [klass databaseIndexProperties]) {
		NSString * colName = [klass resourceMapping][propertyName];
		NSString * colType = nil;
		NSString * type = [klass typeOfPropertyNamed: propertyName];

		if ([colName isEqualToString:@"id"] || [colName isEqualToString:@"data"])
			continue;
			
		if ([type isEqualToString:@"int"])
			colType = @"INTEGER";
		
		if ([type isEqualToString:@"Tc"]) // char or bool
			colType = @"INTEGER";

		else if ([type isEqualToString:@"float"])
			colType = @"REAL";

		else if ([type isEqualToString:@"T@\"NSString\""])
			colType = @"TEXT";
		
		else if ([type isEqualToString:@"T@\"NSDate\""])
			colType = @"INTEGER";

		NSAssert(colType && colName, @"Cannot create an index on the property %@ of type %@", propertyName, type);

		[cols addObject:[NSString stringWithFormat:@"`%@` %@", colName, colType]];
		[colIndexSQLs addObject:[NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS \"%@\" ON \"%@\" (\"%@\")", colName, tableName, colName]];
	}

	NSString * colsString = [cols componentsJoinedByString:@","];
	NSString * tableSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS `%@` (%@);", tableName, colsString];

	[db executeUpdate:tableSQL];
	for (NSString * indexSQL in colIndexSQLs)
		[db executeUpdate:indexSQL];
}

- (void)initializeModelJOINTables:(Class)klass inDatabase:(FMDatabase*)db
{
	// create an additional tables for storing join properties
	for (NSString * property in [klass databaseJoinTableProperties]) {
		NSString * tableName = [NSString stringWithFormat: @"%@-%@", NSStringFromClass(klass), property];
		NSString * tableSQL = [NSString stringWithFormat: @"CREATE TABLE IF NOT EXISTS `%@` (id TEXT KEY, `value` TEXT)", tableName];
		NSString * IDIndexSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS `id` ON `%@` (`id`)", tableName];
		NSString * ValueIndexSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS `value` ON `%@` (`value`)", tableName];
		[db executeUpdate: tableSQL];
		[db executeUpdate: IDIndexSQL];
		[db executeUpdate: ValueIndexSQL];
	}
}

#pragma mark Persisting Objects

- (void)persistModel:(INModelObject *)model
{
	if (![self checkModelTable:[model class]])
		return;
	
	dispatch_async(_queryDispatchQueue, ^{
		[_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
			[self writeModel:model toDatabase:db];
		}];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			// notify providers that this model was updated. This may result in views being updated.
			[[_observers setRepresentation] makeObjectsPerformSelector:@selector(managerDidPersistModels:) withObject:@[model]];
		});
	});
}

- (void)persistModels:(NSArray *)models
{
	if (![self checkModelTable:[[models firstObject] class]])
		return;

	dispatch_async(_queryDispatchQueue, ^{
		[_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
			for (INModelObject * model in models)
				[self writeModel:model toDatabase:db];
		}];

		dispatch_async(dispatch_get_main_queue(), ^{
			// notify providers that models were updated. This may result in views being updated.
			[[_observers setRepresentation] makeObjectsPerformSelector:@selector(managerDidPersistModels:) withObject:models];
		});
	});
}

- (void)unpersistModel:(INModelObject *)model
{
	if (![self checkModelTable:[model class]])
		return;
	
	dispatch_async(_queryDispatchQueue, ^{
		[_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
			if ([model respondsToSelector:@selector(beforeUnpersist:)])
				[model beforeUnpersist: db];
			
			NSString * tableName = [[model class] databaseTableName];
			NSString * query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE id = ?", tableName];
			[db executeUpdate: query withArgumentsInArray:@[[model ID]]];

			for (NSString * property in [[model class] databaseJoinTableProperties]) {
				NSString * propertyTableName = [NSString stringWithFormat: @"%@-%@", tableName, property];
				NSString * deleteSQL = [NSString stringWithFormat: @"DELETE * FROM `%@` WHERE id = `?`", propertyTableName];
				[db executeUpdate: deleteSQL, model.ID];
			}

			if ([model respondsToSelector:@selector(afterUnpersist:)])
				[model afterUnpersist: db];
		}];

		dispatch_async(dispatch_get_main_queue(), ^{
			// notify providers that models were updated. This may result in views being updated.
			[[_observers setRepresentation] makeObjectsPerformSelector:@selector(managerDidUnpersistModels:) withObject:@[model]];
		});
	});
}

- (void)writeModel:(INModelObject *)model toDatabase:(FMDatabase *)db
{
	NSAssert([model ID] != nil, @"Unsaved models should not be written to the cache.");

	if ([model respondsToSelector:@selector(beforePersist:)])
		[model beforePersist: db];

	NSString * tableName = [[model class] databaseTableName];
	NSMutableArray * columns = [@[@"id", @"data"] mutableCopy];
	NSMutableArray * columnPlaceholders = [@[@"?", @"?"] mutableCopy];
	NSMutableArray * values = [NSMutableArray array];

	// serialize the model to JSON that we can store in the 'data' blob
	NSError * jsonError = nil;
	NSData * json = [NSJSONSerialization dataWithJSONObject:[model resourceDictionary] options:NSJSONWritingPrettyPrinted error:&jsonError];

	if (jsonError) {
		NSLog(@"Object serialization failed. Not saved to cache! %@", [jsonError localizedDescription]);
		return;
	}
	[values addObject:[model ID]];
	[values addObject:json];

	// for each index column, grab the model's current value for that key
	for (NSString * propertyName in [[model class] databaseIndexProperties]) {
		NSString * colName = [[model class] resourceMapping][propertyName];
		[columns addObject:colName];
		[columnPlaceholders addObject:@"?"];

		id value = [model valueForKey:propertyName];
		if (!value) value = [NSNull null];
		[values addObject:value];
	}

	NSString * columnsStr = [NSString stringWithFormat:@"`%@`", [columns componentsJoinedByString:@"`,`"]];
	NSString * columnPlaceholdersStr = [columnPlaceholders componentsJoinedByString:@","];

	// execute the query to update the model in database
	NSString * query = [NSString stringWithFormat:@"REPLACE INTO %@ (%@) VALUES (%@)", tableName, columnsStr, columnPlaceholdersStr];
	[db executeUpdate:query withArgumentsInArray:values];
    
	// for each join table property, find all of the items in the join table for
	// this model and delete them. Insert each value back into the table.
	for (NSString * property in [[model class] databaseJoinTableProperties]) {
		NSString * propertyTableName = [NSString stringWithFormat: @"%@-%@", tableName, property];
		NSString * deleteSQL = [NSString stringWithFormat: @"DELETE FROM `%@` WHERE id = ?", propertyTableName];
		NSString * addSQL = [NSString stringWithFormat: @"INSERT INTO `%@` (`id`, `value`) VALUES (\"%@\",?)", propertyTableName, model.ID];
		
		[db executeUpdate:  deleteSQL];
		for (NSString * value in [model valueForKey: property])
			[db executeUpdate: addSQL, value];
	}
	
	// if we encountered errors, try to recover
    if ([db hadError]) {
        if (([[db lastErrorMessage] rangeOfString:@"has no column"].location != NSNotFound) ||
 		    ([[db lastErrorMessage] rangeOfString:@"no such table:"].location != NSNotFound)) {
			// the table schema must have changed. We don't currently do migrations automatically,
			// so let's just blow away the cache for this table and let it get rebuilt
            [db executeUpdate: [NSString stringWithFormat: @"DROP TABLE `%@`", tableName]];
			for (NSString * property in [[model class] databaseJoinTableProperties]) {
				NSString * propertyTableName = [NSString stringWithFormat: @"%@-%@", tableName, property];
				[db executeUpdate: [NSString stringWithFormat: @"DROP TABLE `%@`", propertyTableName]];
			}
            [_initializedModelClasses removeObjectForKey: NSStringFromClass([model class])];
        }
    } else {
		if ([model respondsToSelector:@selector(afterPersist:)])
			[model afterPersist: db];
	}
}

#pragma mark Finding Objects

- (INModelObject*)selectModelOfClass:(Class)klass withID:(NSString *)ID
{
	if (![self checkModelTable:klass])
		return nil;
	
	INModelObject __block * obj = nil;
	[_queue inDatabase:^(FMDatabase * db) {
		FMResultSet * result = nil;
		if (ID) {
			NSString * query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE ID = ? LIMIT 1", [klass databaseTableName]];
			result = [db executeQuery:query withArgumentsInArray:@[ID]];
		} else {
			NSString * query = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT 1", [klass databaseTableName]];
			result = [db executeQuery:query];
		}
		obj = [result nextModelOfClass: klass];
		[result close];
	}];
	return obj;
}

- (void)selectModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate sortedBy:(NSArray *)sortDescriptors limit:(int)limit offset:(int)offset withCallback:(ResultsBlock)callback
{
	NSMutableString * query = [[NSMutableString alloc] initWithFormat:@"SELECT * FROM %@", [klass databaseTableName]];
	INPredicateToSQLConverter * converter = [INPredicateToSQLConverter converterForModelClass: klass];

	if (wherePredicate)
		[query appendString: [converter SQLForPredicate:wherePredicate]];
	
	if ([sortDescriptors count] > 0)
		[query appendString: [converter SQLForSortDescriptors: sortDescriptors]];

	if (limit > 0)
		[query appendFormat:@" LIMIT %d, %d", offset, limit]; // weird ordering, but correct!
	
	[self selectModelsOfClass:klass withQuery:query andParameters:nil andCallback:callback];
}


- (void)selectModelsOfClass:(Class)klass withQuery:(NSString *)query andParameters:(NSDictionary *)arguments andCallback:(ResultsBlock)callback
{
	NSAssert(callback, @"-selectModelsOfClass called without a valid callback.");
	NSAssert(query, @"-selectModelsOfClass called without a valid query.");
	
	if (![self checkModelTable:klass])
		return;

	dispatch_async(_queryDispatchQueue, ^{
		[_queue inDatabase:^(FMDatabase * db) {
			FMResultSet * result = [db executeQuery:query withParameterDictionary:arguments];

			dispatch_sync(dispatch_get_main_queue(), ^{
				NSMutableArray __block * objects = [@[] mutableCopy];
				INModelObject * obj = nil;
				while ((obj = [result nextModelOfClass:klass]))
					[objects addObject:obj];
				
				[result close];

				NSLog(@"%@ RETRIEVED %lu %@s", query, (unsigned long)[objects count], NSStringFromClass(klass));
				if (callback)
					callback(objects);
			});
		}];
	});
}

- (long)countModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate
{
	if (![self checkModelTable:klass])
		return NSNotFound;
	
	NSMutableString * query = [[NSMutableString alloc] initWithFormat:@"SELECT COUNT(*) AS count FROM %@", [klass databaseTableName]];
	if (wherePredicate) {
		INPredicateToSQLConverter * converter = [INPredicateToSQLConverter converterForModelClass: klass];
		[query appendString: [converter SQLForPredicate:wherePredicate]];
	}
	long __block result = NSNotFound;
	[_queue inDatabase:^(FMDatabase *db) {
		FMResultSet * results = [db executeQuery: query];
		result = [results longForColumn:@"count"];
	}];

	return result;
}


@end
