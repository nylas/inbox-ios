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
static NSString * INTagIDTrash = @"trash";
static NSString * INTagIDDraft = @"drafts";
static NSString * INTagIDInbox = @"inbox";
static NSString * INTagIDStarred = @"starred";
static NSString * INTagIDSent = @"sent";

/** A simple wrapper around an Inbox tag. See the Inbox Tags documentation for 
more information about tags: http://inboxapp.com/docs/api#tags
*/
@interface INTag : INModelObject

@property (nonatomic, strong) NSString * providedName;

/**
 @param ID A tag ID. May be a user-generated ID, or one of the built-in Inbox tag IDs:
 INTagIDUnread, INTagIDSent, etc.
 
 @return An INTag model with the given ID.
*/
+ (instancetype)tagWithID:(NSString*)ID;

/**
 Initialize a new INTag model in the given namespace. This should only be used for creating
 new tags, not for retrieving existing tags.
 
 @param namespace The namespace to create the tag in.
 @return An INTag model
*/
- (id)initInNamespace:(INNamespace*)namespace;

/**
 @return The display-ready name of the tag, localized when possible to reflect the
 user's locale.
*/
- (NSString*)name;

/**
 Set the name of the tag. After setting the tag name, you should call -save to commit changes.
 Also note that provider tags (gmail-) cannot be renamed.
 @param name The new tag name
*/
- (void)setName:(NSString*)name;


/**
 @return The color of the tag. When possible, applications should use a tag's color
 in their UI to give users a tag presentation that is consistent and easy to scan.
*/
- (UIColor*)color;

/**
 Save the tag back to the Inbox API. Note that provider tags (gmail-) are not modifiable,
 and in general you can only modify the names of tags.
*/
- (void)save;

@end
