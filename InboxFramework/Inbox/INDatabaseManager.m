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
#import "FMDatabaseAdditions.h"
#import "NSObject+Properties.h"
#import "INModelObject+Uniquing.h"

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
	NSString * tableName = [klass databaseTableName];
	NSMutableArray * cols = [@[@"id TEXT PRIMARY KEY", @"data BLOB"] mutableCopy];
	NSMutableArray * colIndexSQLs = [NSMutableArray array];
    
    [colIndexSQLs addObject: [NSString stringWithFormat: @"CREATE INDEX IF NOT EXISTS `id` ON `%@` (`id`)", tableName]];
    
	for (NSString * propertyName in [klass databaseIndexProperties]) {
		NSString * colName = [klass resourceMapping][propertyName];
		NSString * colType = nil;
		NSString * type = [klass typeOfPropertyNamed: propertyName];

		if ([colName isEqualToString:@"id"])
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
		[colIndexSQLs addObject:[NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS `%@` ON `%@` (`%@`)", colName, tableName, colName]];
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
		NSString * idIndexSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS `id+value` ON `%@` (`id`,`value`)", tableName];
		NSString * valueIndexSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS `value` ON `%@` (`value`)", tableName];
		[db executeUpdate: tableSQL];
		[db executeUpdate: idIndexSQL];
		[db executeUpdate: valueIndexSQL];
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

- (void)unpersistModel:(INModelObject *)model willResaveSameModel:(BOOL)willResave completionBlock:(VoidBlock)completionBlock
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
            if (!willResave)
                [[_observers setRepresentation] makeObjectsPerformSelector:@selector(managerDidUnpersistModels:) withObject:@[model]];
            if (completionBlock) completionBlock();
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
		NSString * deleteSQL = [NSString stringWithFormat: @"DELETE FROM `%@` WHERE `id` = ?", propertyTableName];
		NSString * addSQL = [NSString stringWithFormat: @"INSERT INTO `%@` (`id`, `value`) VALUES (\"%@\",?)", propertyTableName, model.ID];
		
		[db executeUpdate:  deleteSQL, model.ID];
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
        
        [[model class] attachInstance: model];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:INModelObjectChangedNotification object:model];
        });
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
        
        if ([NSThread isMainThread])
            obj = [result nextModelOfClass: klass];
        else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                obj = [result nextModelOfClass: klass];
            });
        }
        [result close];
	}];
	return obj;
}

- (void)selectModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate sortedBy:(NSArray *)sortDescriptors limit:(NSUInteger)limit offset:(NSUInteger)offset withCallback:(ResultsBlock)callback
{
	NSMutableString * query = [[NSMutableString alloc] initWithFormat:@"SELECT * FROM %@", [klass databaseTableName]];
	INPredicateToSQLConverter * converter = [INPredicateToSQLConverter converterForModelClass: klass];

	if (wherePredicate)
		[query appendString: [converter SQLForPredicate:wherePredicate]];
	
	if ([sortDescriptors count] > 0)
		[query appendString: [converter SQLForSortDescriptors: sortDescriptors]];

	if (limit > 0)
		[query appendFormat:@" LIMIT %lu, %lu", (unsigned long)offset, (unsigned long)limit];
    
	[self selectModelsOfClass:klass withQuery:query andParameters:nil andCallback:callback];
}


- (void)selectModelsOfClass:(Class)klass withQuery:(NSString *)query andParameters:(NSDictionary *)arguments andCallback:(ResultsBlock)callback
{
	dispatch_async(_queryDispatchQueue, ^{
        [self selectModelsOfClassSync:klass withQuery:query andParameters:arguments andCallback:callback];
	});
}

- (void)selectModelsOfClassSync:(Class)klass withQuery:(NSString *)query andParameters:(NSDictionary *)arguments andCallback:(ResultsBlock)callback
{
	NSAssert(callback, @"-selectModelsOfClass called without a valid callback.");
	NSAssert(query, @"-selectModelsOfClass called without a valid query.");
	
	if (![self checkModelTable:klass])
		return;
    
    NSMutableArray * __block __results = [NSMutableArray array];
    NSDate * __block startDB = nil;
    NSDate * __block endDB = nil;
    NSDate * __block startMT = nil;
    NSDate * __block endMT = nil;
    
    // Execute the actual database query on the database's dispatch queue and read the
    // resulting data into shared memory.
    [_queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        startDB = [NSDate date];
        FMResultSet * resultSet = [db executeQuery:query withParameterDictionary:arguments];
        endDB = [NSDate date];
        while ([resultSet next]) {
            NSData * jsonData = [resultSet dataForColumn:@"data"];
            [__results addObject: jsonData];
        }
        [resultSet close];
    }];
    
    // Inflate the data into JSON on our background query processing queue.
    for (int ii = (int)[__results count] - 1; ii >= 0; ii --) {
        NSError * err = nil;
        NSData * jsonData = [__results objectAtIndex: ii];
        NSDictionary * json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&err];
        if (!err) {
            [__results replaceObjectAtIndex: ii withObject: json];
        } else {
            [__results removeObjectAtIndex: ii];
        }
    }
    
    VoidBlock processResults = ^{
        startMT = [NSDate date];
        for (int ii = (int)[__results count] - 1; ii >= 0; ii --) {
            BOOL created = NO;
            NSDictionary * json = [__results objectAtIndex: ii];
            INModelObject * model = [klass attachedInstanceMatchingID: json[@"id"] createIfNecessary:YES didCreate: &created];
            if (created) {
                [model updateWithResourceDictionary: json];
                [model setup];
            }
            
            [__results replaceObjectAtIndex:ii withObject:model];
        }
        
        endMT = [NSDate date];
        NSLog(@"%@ RETRIEVED %lu %@s. \nDatabase thread time: %f sec\nMain thread time: %f sec\n", query, (unsigned long)[__results count], NSStringFromClass(klass), [endDB timeIntervalSinceDate:startDB], [endMT timeIntervalSinceDate: startMT]);
        if (callback)
            callback(__results);
    };
    
    // Incorporate the JSON into the living model objects. This must always happen
    // on the main thread. If we were called from the background, let's do this on the main
    // queue in the next run through the run loop. If we're already on the main queue, make sure
    // we do everything immediately - this is a synchronous request! (Probably for a very
    // small number of known models, like namespaces, that will be returned.)
    if ([[NSThread currentThread] isMainThread])
        processResults();
    else
        dispatch_async(dispatch_get_main_queue(), processResults);
}

- (void)countModelsOfClass:(Class)klass matching:(NSPredicate *)wherePredicate withCallback:(LongBlock)callback
{
	dispatch_async(_queryDispatchQueue, ^{
        if (![self checkModelTable:klass])
            return;
           
        // because our predicate is sometimes converted to a complex where clause with JOINs and GROUP BY
        // statements, we can't just count results. We have to use a sub-select and then count that.
        INPredicateToSQLConverter * converter = [INPredicateToSQLConverter converterForModelClass: klass];

        long __block result = NSNotFound;
        [_queue inDatabase:^(FMDatabase *db) {
            NSString * sql = [NSString stringWithFormat: @"SELECT COUNT(1) as count FROM (SELECT 1 FROM %@ %@)", [klass databaseTableName], [converter SQLForPredicate:wherePredicate]];
            result = [db longForQuery: sql];
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback)
                callback(result);
        });
    });
}


@end
