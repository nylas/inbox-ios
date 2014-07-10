//
//  INMarkMessageAsReadTask.m
//  InboxFramework
//
//  Created by Ben Gotow on 6/17/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMarkMessageAsReadTask.h"

@implementation INMarkMessageAsReadTask


- (NSURLRequest *)buildAPIRequest
{
    NSAssert([self model], @"INMarkMessageAsReadTask asked to buildRequest with no access to a message model!");
	NSAssert([[self model] namespaceID], @"INMarkMessageAsReadTask asked to buildRequest with no namespace!");
    
    NSError * error = nil;
    NSString * path = [self.model resourceAPIPath];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].AF.baseURL] absoluteString];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params setObject:@(NO) forKey:@"unread"];
    
	return [[[[INAPIManager shared] AF] requestSerializer] requestWithMethod:@"PUT" URLString:url parameters:params error:&error];
}

- (void)applyLocally
{
    [(INMessage*)self.model setUnread: NO];
    [[INDatabaseManager shared] persistModel: self.model];
}

- (void)rollbackLocally
{
    [(INMessage*)self.model setUnread: YES];
    [[INDatabaseManager shared] persistModel: self.model];
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    return ([[other model] isEqual: self.model] && [other isKindOfClass: [self class]]);
}

@end
