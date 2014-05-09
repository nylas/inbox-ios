//
//  NSPredicate+Inspection.h
//  BigSur
//
//  Created by Ben Gotow on 5/1/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSPredicate (Inspection)

- (BOOL)containsOrMatches:(NSString*)expression;

@end
