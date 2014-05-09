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

@interface INThread : INModelObject

@property (nonatomic, strong) NSString * subject;
@property (nonatomic, strong) NSString * snippet;
@property (nonatomic, strong) NSArray * participants;
@property (nonatomic, strong) NSDate * lastMessageDate;
@property (nonatomic, strong) NSArray * messageIDs;

- (INModelProvider*)newMessageProvider;

@end
