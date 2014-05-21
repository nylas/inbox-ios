//
//  INThread.h
//  BigSur
//
//  Created by Ben Gotow on 4/28/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INModelProvider.h"
#import "INMessage.h"

@class INTag;

@interface INThread : INModelObject

@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * snippet;
@property (nonatomic, strong) NSArray * participants;
@property (nonatomic, strong) NSDate * lastMessageDate;
@property (nonatomic, strong) NSArray * messageIDs;
@property (nonatomic, strong) NSArray * tagIDs;
@property (nonatomic, assign) BOOL unread;

- (NSArray*)tags;
- (NSArray*)tagIDs;
- (BOOL)hasTagWithID:(NSString*)ID;

- (INModelProvider*)newMessageProvider;
- (INMessage*)currentDraft;

@end
