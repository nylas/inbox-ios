//
//  NSError+InboxErrors.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/27/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (InboxErrors)

+ (NSError*)inboxErrorWithFormat:(NSString *)format, ...;
+ (NSError*)inboxErrorWithDescription:(NSString *)desc;

@end
