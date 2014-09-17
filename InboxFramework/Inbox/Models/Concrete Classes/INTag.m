//
//  INLabel.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INTag.h"
#import "INNamespace.h"
#import "INSaveTagTask.h"

@implementation INTag

+ (instancetype)tagWithID:(NSString*)ID
{
    return [self instanceWithID: ID inNamespaceID: nil];
}

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary:@{
        @"providedName": @"name"
    }];
	return mapping;
}

+ (NSString *)resourceAPIName
{
	return @"tags";
}

- (id)initInNamespace:(INNamespace*)namespace
{
    NSAssert(namespace, @"initInNamespace: called with a nil namespace.");
    self = [super init];
    if (self) {
        [self setNamespaceID: [namespace ID]];
    }
    return self;
}

- (NSString*)name
{
    // pretend we have localization
    NSDictionary * localized = @{INTagIDArchive: @"Archive", INTagIDInbox: @"Inbox", INTagIDTrash: @"Trash", INTagIDUnread: @"Unread", INTagIDSent: @"Sent", INTagIDStarred: @"Starred"};
    if ([localized objectForKey: self.ID])
        return [localized objectForKey: self.ID];
    if (self.providedName)
        return self.providedName;
    return [self.ID capitalizedString];
}

- (void)setName:(NSString*)name
{
    // in the future, check the readonly flag here
    _providedName = name;
}

- (UIColor*)color
{
	NSInteger count = 0;
	for (int ii = 0; ii < [[self name] length]; ii ++)
		count += [[self name] characterAtIndex:ii];
	
	return [UIColor colorWithHue:(count % 1000) / 1000.0 saturation:0.8 brightness:0.6 alpha:1];
}

- (void)save
{
    INSaveTagTask * save = [INSaveTagTask operationForModel: self];
    [[INAPIManager shared] queueTask: save];
}

@end
