//
//  INMessage.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INThread.h"
#import "NSString+FormatConversion.h"
#import "INNamespace.h"

@implementation INMessage


+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
 	 @"subject": @"subject",
 	 @"body": @"body",
	 @"threadID": @"thread",
	 @"date": @"date",
	 @"from": @"from",
	 @"to": @"to",
     @"isDraft": @"is_draft"
	}];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"messages";
}

+ (NSArray *)databaseIndexProperties
{
	return [[super databaseIndexProperties] arrayByAddingObjectsFromArray: @[@"threadID", @"subject", @"date"]];
}

- (id)initAsDraftIn:(INNamespace*)namespace
{
    NSAssert(namespace, @"initAsDraftIn: called with a nil namespace.");
    INMessage * m = [[INMessage alloc] init];
    [m setNamespaceID: [namespace ID]];
    return m;
}

- (id)initAsDraftIn:(INNamespace*)namespace inReplyTo:(INThread*)thread
{
    NSAssert(namespace, @"initAsDraftIn: called with a nil namespace.");
    INMessage * m = [[INMessage alloc] initAsDraftIn: namespace];
    
    NSMutableArray * recipients = [NSMutableArray array];
    for (NSDictionary * recipient in [thread participants])
        if (![[[INAPIManager shared] namespaceEmailAddresses] containsObject: recipient[@"email"]])
            [recipients addObject: recipient];
    
    [m setTo: recipients];
    [m setSubject: thread.subject];
    [m setThreadID: [thread ID]];
    
    return m;
    
}

- (INThread*)thread
{
    if (!_threadID)
        return nil;
    return [INThread instanceWithID: [self threadID] inNamespaceID: [self namespaceID]];
}

@end
