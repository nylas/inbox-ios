#import <objc/objc.h>
#import "Kiwi.h"
#import "INModelProvider.h"
#import "INModelProvider+Private.h"
#import "INMessage.h"
#import "INDatabaseManager.h"
#import "NSPredicate+Inspection.h"

KWFutureObject * dispatch_async_and_return_exception_future(dispatch_block_t block) {
	NSException __block * exception = nil;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		@try {
			block();
		} @catch (NSException * e) {
			exception = e;
		}
	});
	return expectFutureValue(exception);
}


SPEC_BEGIN(INModelProviderTests)

INModelProvider __block * provider;
beforeEach(^{
	provider = [[INModelProvider alloc] initWithClass:[INMessage class] andNamespaceID:@"1" andUnderlyingPredicate:nil];
});

describe(@"initWithClass:andNamespaceID:andUnderlyingPredicate:", ^{
	it(@"should register the provider for database updates", ^{
		NSHashTable * observers = [[INDatabaseManager shared] observers];
		[[theValue([observers containsObject: provider]) should] beTrue];
	});
});

describe(@"setItemSortDescriptors:", ^{
	it(@"should trigger an eventual refresh", ^{
		NSSortDescriptor * descriptor = [NSSortDescriptor sortDescriptorWithKey: @"subject" ascending:NO];
		[provider setItemSortDescriptors: @[descriptor]];
		[[provider shouldEventually] receive:@selector(refresh)];
	});
	it(@"should not refresh if the sort descriptor is identical to the current one", ^{
		[provider setItemSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"subject" ascending:NO]]];
		[provider refresh]; // clears the queued call to 'refresh'
		[provider setItemSortDescriptors: @[[NSSortDescriptor sortDescriptorWithKey: @"subject" ascending:NO]]];
		[[provider shouldNotEventually] receive:@selector(refresh)];
	});
});

describe(@"setItemFilterPredicate:", ^{
	it(@"should trigger an eventual refresh", ^{
		[provider setItemFilterPredicate: [NSPredicate predicateWithFormat:@"ID = 4"]];
		[[provider shouldEventually] receive:@selector(refresh)];
	});
	it(@"should not refresh if the predicate is identical to the current one", ^{
		[provider setItemFilterPredicate: [NSPredicate predicateWithFormat:@"ID = 4"]];
		[provider refresh]; // clears the queued call to 'refresh'
		[provider setItemFilterPredicate: [NSPredicate predicateWithFormat:@"ID = 4"]];
		[[provider shouldNotEventually] receive:@selector(refresh)];
	});
});

describe(@"setItemRange:", ^{
	it(@"should trigger an eventual refresh", ^{
		[provider setItemRange: NSMakeRange(0, 100)];
		[[provider shouldEventually] receive:@selector(refresh)];
	});
	it(@"should not refresh if the range is identical to the current one", ^{
		[provider setItemRange:NSMakeRange(0, 100)];
		[provider refresh]; // clears the queued call to 'refresh'
		[provider setItemRange:NSMakeRange(0, 100)];
		[[provider shouldNotEventually] receive:@selector(refresh)];
	});
});

describe(@"refresh", ^{
	it(@"should fetch items from cache", ^{
		[[provider should] receive: @selector(fetchFromCache)];
		[provider refresh];
	});

	context(@"when cache policy is INModelProviderCacheThenNetwork", ^{
		it(@"should trigger a fetch from the API", ^{
			[provider setItemCachePolicy: INModelProviderCacheThenNetwork];
			[[provider should] receive:@selector(fetchFromAPI)];
			[provider refresh];
		});
	});

	context(@"when cache policy is INModelProviderCacheOnly", ^{
		it(@"should not trigger a fetch from the API", ^{
			[provider setItemCachePolicy: INModelProviderCacheOnly];
			[[provider shouldNot] receive:@selector(fetchFromAPI)];
			[provider refresh];
		});
	});
});

describe(@"fetchPredicate", ^{
	it(@"should return a predicate that includes the namespace constraint", ^{
		NSPredicate * predicate = [provider fetchPredicate];
		[[theValue([predicate containsOrMatches: @"namespaceID == \"1\""]) should] beTrue];
	});

	it(@"should return a predicate that includes the underlying predicate if one exists", ^{
		NSPredicate * underlying = [NSPredicate predicateWithFormat:@"threadID = %@", @"2"];
		provider = [[INModelProvider alloc] initWithClass:[INMessage class] andNamespaceID:@"1" andUnderlyingPredicate: underlying];
	
		NSPredicate * predicate = [provider fetchPredicate];
		[[theValue([predicate containsOrMatches: @"threadID == \"2\""]) should] beTrue];
	});
	
	it(@"should return a predicate that includes the item filter predicate", ^{
		NSPredicate * filterPredicate = [NSPredicate predicateWithFormat:@"subject LIKE %@", @"Happy Day"];
		[provider setItemFilterPredicate: filterPredicate];
		
		NSPredicate * predicate = [provider fetchPredicate];
		[[theValue([predicate containsOrMatches: @"subject LIKE \"Happy Day\""]) should] beTrue];
	});
	
	it(@"should return a compound predicate ANDing the others if more than one is specified", ^{
		NSPredicate * underlyingPredicate = [NSPredicate predicateWithFormat:@"threadID = %@", @"2"];
		provider = [[INModelProvider alloc] initWithClass:[INMessage class] andNamespaceID:@"1" andUnderlyingPredicate: underlyingPredicate];

		NSPredicate * filterPredicate = [NSPredicate predicateWithFormat:@"subject LIKE %@", @"Happy Day"];
		[provider setItemFilterPredicate: filterPredicate];
		
		NSCompoundPredicate * result = (NSCompoundPredicate *)[provider fetchPredicate];
		[[theValue([result compoundPredicateType]) should] equal: theValue((NSAndPredicateType))];
		[[[result subpredicates] should] contain: filterPredicate];
		[[[result subpredicates] should] contain: underlyingPredicate];
	});
});

describe(@"managerDidPersistModels:", ^{
	NSMutableArray __block * currentItems;
	NSMutableArray __block * savedItems;
	beforeEach(^{
		currentItems = [NSMutableArray array];
		savedItems = [NSMutableArray array];
		
		for (int ii = 0; ii < 10; ii ++) {
			[currentItems addObject: [[INMessage alloc] init]];
		}
		[provider setItems: currentItems];
		[savedItems addObject: currentItems[2]];
	});

	it(@"should only be run on the main thread", ^{
		KWFutureObject * exception = dispatch_async_and_return_exception_future(^{
			[provider managerDidPersistModels: @[]];
		});
		[[exception shouldEventually] beNonNil];
	});

	context(@"if the delegate responds to provider:dataAltered:", ^{
		it(@"should send changes", ^{
			id delegateMock = [KWMock mockForProtocol: @protocol(INModelProviderDelegate)];
			[[delegateMock should] receive:@selector(provider:dataAltered:)];
			[provider setDelegate: delegateMock];
			[provider managerDidPersistModels: savedItems];
		});
	});

	context(@"if the delegate only responds to providerDataChanged:", ^{
		it(@"should call that instead", ^{
			// FAILING:
			// Filed bug report: https://github.com/allending/Kiwi/issues/511
			
			id delegateMock = [KWMock mock];
			[delegateMock stub: @selector(providerDataChanged:)];
			BOOL responds = [delegateMock respondsToSelector: @selector(providerDataChanged:)];
			
			[[delegateMock should] receive:@selector(providerDataChanged:)];
			[provider setDelegate: delegateMock];
			[provider managerDidPersistModels: savedItems];
		});
	});
});

describe(@"managerDidUnpersistModels:", ^{

	NSMutableArray __block * items = nil;
	NSMutableArray __block * twoItems = nil;
	beforeEach(^{
		items = [NSMutableArray array];
		for (int ii = 0; ii < 5; ii ++) {
			[items addObject: [[INMessage alloc] init]];
		}
		
		twoItems = [NSMutableArray array];
		[twoItems addObject: items[1]];
		[twoItems addObject: items[4]];

		// not usually called directly, but we want to set up the collection to remove items
		[provider setItems: items];
	});

	it(@"should only be run on the main thread", ^{
		KWFutureObject * exception = dispatch_async_and_return_exception_future(^{
			[provider managerDidUnpersistModels: @[]];
		});
		[[exception shouldEventually] beNonNil];
	});
	
	context(@"if the delegate responds to provider:dataAltered:", ^{
		it(@"should send a correct set of changes", ^{
			id delegateMock = [KWMock mockForProtocol: @protocol(INModelProviderDelegate)];
			KWCaptureSpy * changesSpy = [delegateMock captureArgument:@selector(provider:dataAltered:) atIndex:0];
			[provider setDelegate: delegateMock];
			[provider managerDidUnpersistModels: twoItems];

			INModelProviderChangeSet * changeSet = [changesSpy argument];
			[[[changeSet changes] should] haveCountOf: 2];

			INModelProviderChange * change1 = [changeSet changes][0];
			[[[change1 item] should] equal: twoItems[0]];
			[[theValue([change1 index]) should] equal: theValue(1)];

			INModelProviderChange * change2 = [changeSet changes][1];
			[[[change2 item] should] equal: twoItems[1]];
			[[theValue([change2 index]) should] equal: theValue(4)];
		});
		
		it(@"should not send an empty change set", ^{
			NSMutableArray * twoItemsNotInSet = [NSMutableArray array];
			for (int ii = 0; ii < 2; ii ++)
				[twoItemsNotInSet addObject: [[INMessage alloc] init]];
				
			id delegateMock = [KWMock mockForProtocol: @protocol(INModelProviderDelegate)];
			[[delegateMock shouldNot] receive: @selector(provider:dataAltered:)];
			[provider managerDidUnpersistModels: twoItemsNotInSet];
		});
	});
	
	context(@"if the delegate only responds to providerDataChanged:", ^{
		it(@"should call providerDataChanged:", ^{
			id delegateMock = [KWMock mock];
			[delegateMock expect: @selector(providerDataChanged:)];

			[provider setDelegate: delegateMock];
			[provider managerDidUnpersistModels: twoItems];
		});
	});
});

describe(@"managerDidReset", ^{
	it(@"should only be run on the main thread", ^{
		KWFutureObject * exception = dispatch_async_and_return_exception_future(^{
			[provider managerDidReset];
		});
		[[exception shouldEventually] beNonNil];
	});

	it(@"should reload the items array", ^{
		NSMutableArray * oldItems = [NSMutableArray array];
		[oldItems addObject: [[INMessage alloc] init]];
		[provider setItems: oldItems];
		[provider managerDidReset];
		
		[[expectFutureValue([provider items]) shouldNotEventually] beIdenticalTo: oldItems];
	});
});

SPEC_END