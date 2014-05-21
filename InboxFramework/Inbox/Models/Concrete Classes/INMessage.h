//
//  INMessage.h
//  BigSur
//
//  Created by Ben Gotow on 4/30/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"

@class INThread;
@class INNamespace;

@interface INMessage : INModelObject

@property (nonatomic, strong) NSString * body;
@property (nonatomic, strong) NSDate * date;
@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * threadID;
@property (nonatomic, strong) NSArray * from;
@property (nonatomic, strong) NSArray * to;
@property (nonatomic, assign) BOOL isDraft;

- (id)initAsDraftIn:(INNamespace*)namespace;
- (id)initAsDraftIn:(INNamespace*)namespace inReplyTo:(INThread*)thread;

- (INThread*)thread;

#pragma mark Operations on Drafts

- (void)save;
- (void)send;
- (void)delete;


@end
