//
//  NSDictionary+FormatConversion.h
//  BigSur
//
//  Created by Ben Gotow on 5/1/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (FormatConversion)

- (id)objectForKey:(id)key asType:(NSString*)type;

@end
