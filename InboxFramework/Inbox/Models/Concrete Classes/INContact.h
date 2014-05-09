//
//  INContact.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"

@interface INContact : INModelObject

@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * emailAddress;
@property (nonatomic, strong) NSString * source;
@property (nonatomic, strong) NSString * providerName;
@property (nonatomic, strong) NSString * accountID;
@property (nonatomic, strong) NSString * UID;

@end
