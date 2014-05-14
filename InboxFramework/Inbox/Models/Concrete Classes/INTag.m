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
	return [UIColor colorWithWhite:0.6 alpha:1];
}

@end
