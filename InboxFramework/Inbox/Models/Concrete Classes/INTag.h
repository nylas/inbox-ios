//
//  INLabel.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"

static NSString * INTagIDUnread = @"unread";
static NSString * INTagIDUnseen = @"unseen";
static NSString * INTagIDArchive = @"archive";
static NSString * INTagIDDraft = @"drafts";
static NSString * INTagIDInbox = @"inbox";
static NSString * INTagIDStarred = @"starred";
static NSString * INTagIDSent = @"sent";

/** A simple wrapper around an Inbox tag. See the Inbox Tags documentation for 
more information about tags: http://inboxapp.com/docs/api#tags
*/
@interface INTag : INModelObject

/**
 @param ID A tag ID. May be a user-generated ID, or one of the built-in Inbox tag IDs:
 INTagIDUnread, INTagIDSent, etc.
 
 @return An INTag model with the given ID.
*/
+ (instancetype)tagWithID:(NSString*)ID;

/**
 @return The display-ready name of the tag, localized when possible to reflect the
 user's locale.
*/
- (NSString*)name;

/**
 @return The color of the tag. When possible, applications should use a tag's color
 in their UI to give users a tag presentation that is consistent and easy to scan.
*/
- (UIColor*)color;

@end
