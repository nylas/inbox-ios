//
//  PDKeychainBindings.h
//  PDKeychainBindingsController
//
//  Created by Carl Brown on 7/10/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

#import <Foundation/Foundation.h>


@interface INPDKeychainBindings : NSObject {
@private
    
}

+ (INPDKeychainBindings *)sharedKeychainBindings;

- (id)objectForKey:(NSString *)defaultName;
- (void)setObject:(NSString *)value forKey:(NSString *)defaultName;
- (void)setString:(NSString *)value forKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;

- (NSString *)stringForKey:(NSString *)defaultName;
@end
