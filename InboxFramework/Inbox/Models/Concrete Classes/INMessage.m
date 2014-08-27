//
//  INMessage.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INMessage.h"
#import "INThread.h"
#import "INFile.h"
#import "NSString+FormatConversion.h"
#import "INNamespace.h"
#import "INMarkMessageAsReadTask.h"

@implementation INMessage


+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
 	 @"subject": @"subject",
 	 @"body": @"body",
     @"snippet": @"snippet",
	 @"threadID": @"thread",
	 @"date": @"date",
	 @"from": @"from",
	 @"to": @"to",
	 @"cc": @"cc",
     @"bcc": @"bcc",
     @"unread": @"unread",
	 @"attachmentIDs":@"files"
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

- (INThread*)thread
{
    if (!_threadID)
        return nil;
    return [INThread instanceWithID: [self threadID] inNamespaceID: [self namespaceID]];
}

- (NSArray*)attachments
{
	NSMutableArray * attachments = [NSMutableArray array];
	for (NSString * ID in _attachmentIDs) {
		INFile * attachment = [INFile instanceWithID:ID inNamespaceID:[self namespaceID]];
		[attachments addObject: attachment];
	}
	return attachments;
}

- (void)markAsRead
{
    if (self.unread == NO)
        return;

    INMarkMessageAsReadTask * task = [[INMarkMessageAsReadTask alloc] initWithModel: self];
    [[INAPIManager shared] queueTask: task];
}


@end
