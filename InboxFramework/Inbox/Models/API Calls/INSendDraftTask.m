//
//  INSendDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSendDraftTask.h"
#import "INDeleteDraftTask.h"
#import "INSaveDraftTask.h"
#import "INTag.h"

@implementation INSendDraftTask

- (BOOL)canStartAfterTask:(INAPITask *)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftTask class]])
        return NO;
    return YES;
}

- (BOOL)canCancelPendingTask:(INAPITask*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftTask class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftTask class]])
        return YES;
    return NO;
}

- (NSURLRequest *)buildAPIRequest
{
    NSAssert(self.model, @"INSendDraftChange asked to buildRequest with no model!");
	NSAssert([self.model namespaceID], @"INSendDraftChange asked to buildRequest with no namespace!");
	
    NSError * error = nil;
    NSString * sendPath = [NSString stringWithFormat:@"/n/%@/send", [self.model namespaceID]];
    NSString * url = [[NSURL URLWithString:sendPath relativeToURL:[INAPIManager shared].baseURL] absoluteString];
    
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:@{@"draft_id": [self.model ID]} error:&error];
}

- (NSArray*)dependenciesIn:(NSArray*)others
{
	NSMutableArray * dependencies = [NSMutableArray array];
	for (INAPITask * other in others) {
		if (other == self)
			continue;
		
		if ([other isKindOfClass: [INSaveDraftTask class]] && [[other model] isEqual: [self model]])
			[dependencies addObject: other];
	}
	return dependencies;
}

@end
