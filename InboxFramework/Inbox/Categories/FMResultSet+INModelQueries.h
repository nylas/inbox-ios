//
//  FMResultSet+INModelQueries.h
//  BigSur
//
//  Created by Ben Gotow on 4/22/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "FMResultSet.h"
#import "INModelObject.h"

@interface FMResultSet (INModelQueries)

- (INModelObject *)nextModelOfClass:(Class)klass;

@end
