//
//  INLabel.m
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INTag.h"
#import "INNamespace.h"

@implementation INTag

+ (instancetype)tagWithID:(NSString*)ID
{
    return [self instanceWithID: ID inNamespaceID: nil];
}

+ (NSString *)resourceAPIName
{
	return @"tags";
}

- (NSString*)name
{
    // pretend we have localization
    NSDictionary * localized = @{INTagIDArchive: @"Archive", INTagIDInbox: @"Inbox", INTagIDUnread: @"Unread", INTagIDSent: @"Sent", INTagIDFlagged: @"Flagged", INTagIDDraft: @"Draft"};
    if ([localized objectForKey: self.ID])
        return [localized objectForKey: self.ID];
    return self.ID;
}

- (UIColor*)color
{
	NSInteger count = 0;
	for (int ii = 0; ii < [[self name] length]; ii ++)
		count += [[self name] characterAtIndex:ii];
	
	return [UIColor colorWithHue:(count % 1000) / 1000.0 saturation:0.8 brightness:0.6 alpha:1];
}

@end
