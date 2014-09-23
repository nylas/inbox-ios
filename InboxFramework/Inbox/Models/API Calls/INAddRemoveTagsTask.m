//
//  INAddRemoveTagsChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSaveTagTask.h"
#import "INAddRemoveTagsTask.h"
#import "INThread.h"
#import "INMessage.h"
#import "INTag.h"

@implementation INAddRemoveTagsTask


- (NSMutableArray *)tagIDsToAdd
{
    if (!self.data[@"tagIDsToAdd"])
        [self.data setObject: [NSMutableArray array] forKey:@"tagIDsToAdd"];
    return self.data[@"tagIDsToAdd"];
}

- (NSMutableArray *)tagIDsToRemove
{
    if (!self.data[@"tagIDsToRemove"])
        [self.data setObject: [NSMutableArray array] forKey:@"tagIDsToRemove"];
    return self.data[@"tagIDsToRemove"];
}

- (NSMutableArray *)tagIDStringsToAdd
{
    NSMutableArray * tagIDStrings = [NSMutableArray array];
    for (NSObject * tag in [self tagIDsToAdd]) {
        if ([tag isKindOfClass: [INTag class]]) {
            [tagIDStrings addObject: [(INTag*)tag ID]];
        } else {
            [tagIDStrings addObject: (NSString*)tag];
        }
    }
    return tagIDStrings;
}

- (NSMutableArray *)tagIDStringsToRemove
{
    NSMutableArray * tagIDStrings = [NSMutableArray array];
    for (NSObject * tag in [self tagIDsToRemove]) {
        if ([tag isKindOfClass: [INTag class]]) {
            [tagIDStrings addObject: [(INTag*)tag ID]];
        } else {
            [tagIDStrings addObject: (NSString*)tag];
        }
    }
    return tagIDStrings;
}

- (INThread*)thread
{
    if ([self.model isKindOfClass: [INThread class]])
        return (INThread*)self.model;
    if ([self.model isKindOfClass: [INMessage class]])
        return [(INMessage*)self.model thread];
    return nil;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert([self thread], @"INSaveDraftChange asked to buildRequest with no access to a thread model!");
    NSAssert([[self thread] namespaceID], @"INSaveDraftChange asked to buildRequest with no namespace!");
    
    NSError * error = nil;
    NSString * path = [[self thread] resourceAPIPath];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].AF.baseURL] absoluteString];
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params setObject:[self tagIDStringsToAdd] forKey:@"add_tags"];
    [params setObject:[self tagIDStringsToRemove] forKey:@"remove_tags"];
    
    return [[[[INAPIManager shared] AF] requestSerializer] requestWithMethod:@"PUT" URLString:url parameters:params error:&error];
}

- (void)applyLocally
{
    NSMutableArray * newTagIDs = [NSMutableArray arrayWithArray: [[self thread] tagIDs]];
    [newTagIDs addObjectsFromArray: self.tagIDStringsToAdd];
    [newTagIDs removeObjectsInArray: self.tagIDStringsToRemove];
    [[self thread] setTagIDs: newTagIDs];
    [[INDatabaseManager shared] persistModel: [self thread]];
}

- (void)rollbackLocally
{
    NSMutableArray * newTagIDs = [NSMutableArray arrayWithArray: [[self thread] tagIDs]];
    [newTagIDs removeObjectsInArray: self.tagIDStringsToAdd];
    [newTagIDs addObjectsFromArray: self.tagIDStringsToRemove];
    [[self thread] setTagIDs: newTagIDs];
    [[INDatabaseManager shared] persistModel: [self thread]];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    if ([responseObject isKindOfClass: [NSDictionary class]]) {
        [[self thread] updateWithResourceDictionary: responseObject];
        [[INDatabaseManager shared] persistModel: [self thread]];
    }
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INAddRemoveTagsTask class]]) {
        INAddRemoveTagsTask * otherTask = (INAddRemoveTagsTask*)other;
        
        // do we add ALL the tags 'other' is removing?
        BOOL invalidatesRemoved = [[NSSet setWithArray: [otherTask tagIDStringsToRemove]] isSubsetOfSet:[NSSet setWithArray: [self tagIDStringsToAdd]]];
        
        // do we remove ALL the tags 'other' is adding?
        BOOL invalidatesAdded = [[NSSet setWithArray: [otherTask tagIDStringsToAdd]] isSubsetOfSet:[NSSet setWithArray: [self tagIDStringsToRemove]]];
        
        // if we do both, we effectively null the effect of this operation
        return invalidatesRemoved && invalidatesAdded;
    }
    return NO;
}

- (NSArray *)dependenciesIn:(NSArray *)others
{
    NSMutableArray * dependencies = [NSMutableArray array];
    for (INAPITask * other in others) {
        if (other == self) {
            continue;
        }
        if ([other isKindOfClass: [INSaveTagTask class]] && [[NSSet setWithArray:[self tagIDStringsToAdd]] containsObject:[[other model] ID]]) {
            [dependencies addObject: other];
        }
    }
    return dependencies;
}


@end
