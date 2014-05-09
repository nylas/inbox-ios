//
//  NSString+FormatConversion.h
//  Mib.io
//
//  Created by Ben Gotow on 6/7/12.
//  Copyright (c) 2012 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FormatConversion)

+ (NSString *)stringWithDate:(NSDate *)date format:(NSString *)f;
- (NSDate *)dateValueWithFormat:(NSString *)f;
- (NSString *)md5Value;

+ (NSString *)generateUUIDWithExtension:(NSString *)ext;
- (NSString *)urlencode;

- (id)asJSONObjectOfClass:(Class)klass;

@end
