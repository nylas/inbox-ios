//
//  INSendDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/20/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSendDraftChange.h"
#import "INDeleteDraftChange.h"
#import "INTag.h"

@implementation INSendDraftChange

- (BOOL)canStartAfterChange:(INModelChange *)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftChange class]])
        return NO;
    return YES;
}

- (BOOL)canCancelPendingChange:(INModelChange*)other
{
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INSendDraftChange class]])
        return YES;
    if ([[other model] isEqual: self.model] && [other isKindOfClass: [INDeleteDraftChange class]])
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
	for (INModelChange * other in others) {
		if (other == self)
			continue;
		
		if ([other isKindOfClass: [INSaveDraftChange class]] && [[other model] isEqual: [self model]])
			[dependencies addObject: other];
	}
	return dependencies;
}

@end
