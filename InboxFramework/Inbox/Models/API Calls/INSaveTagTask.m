//
//  INSaveTagTask.m
//  InboxFramework
//
//  Created by Ben Gotow on 9/17/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSaveTagTask.h"
#import "INTag.h"
#import "INDatabaseManager.h"

@implementation INSaveTagTask

- (BOOL)canStartAfterTask:(INAPITask *)other
{
    return YES;
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSaveTagTask class]])
        return YES;
    return NO;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert(self.model, @"INSaveTagTask asked to buildRequest with no model!");
    NSAssert([self.model namespaceID], @"INSaveTagTask asked to buildRequest with no namespace!");
    
    NSError * error = nil;
    NSString * path = nil;
    
    if ([self.model isUnsynced])
        path = [NSString stringWithFormat:@"/n/%@/tags", [self.model namespaceID]];
    else
        path = [NSString stringWithFormat:@"/n/%@/tags/%@", [self.model namespaceID], [self.model ID]];
    
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].AF.baseURL] absoluteString];
    NSMutableDictionary * params = [[self.model resourceDictionary] mutableCopy];
    [params removeObjectForKey: @"id"];
    [params removeObjectForKey: @"namespace_id"];
    
    return [[[[INAPIManager shared] AF] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:params error:&error];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    if (![responseObject isKindOfClass: [NSDictionary class]])
        return NSLog(@"SaveTag weird response: %@", responseObject);
    
    INTag * tag = (INTag *)[self model];
    
    // remove the tag from the local cache and then update it with the API response
    // and save it again. This is important, because the JSON that comes back from an
    // initial save gives the tag an ID and we want to replace the old tag.
    [[INDatabaseManager shared] unpersistModel: tag willResaveSameModel:YES];
    [tag updateWithResourceDictionary: responseObject];
    [[INDatabaseManager shared] persistModel: tag];
}

- (void)applyLocally
{
    [[INDatabaseManager shared] persistModel: [self model]];
}

- (void)rollbackLocally
{
}

@end
