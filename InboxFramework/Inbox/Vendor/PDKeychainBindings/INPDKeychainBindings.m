//
//  PDKeychainBindings.m
//  PDKeychainBindings
//
//  Created by Carl Brown on 7/10/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

#import "INPDKeychainBindings.h"
#import "INPDKeychainBindingsController.h"

@implementation INPDKeychainBindings

+ (INPDKeychainBindings *)sharedKeychainBindings
{
	return [[INPDKeychainBindingsController sharedKeychainBindingsController] keychainBindings];
}

- (id)objectForKey:(NSString *)defaultName {
    //return [[[PDKeychainBindingsController sharedKeychainBindingsController] valueBuffer] objectForKey:defaultName];
    return [[INPDKeychainBindingsController sharedKeychainBindingsController] valueForKeyPath:[NSString stringWithFormat:@"values.%@",defaultName]];
}

- (void)setObject:(NSString *)value forKey:(NSString *)defaultName {
    [[INPDKeychainBindingsController sharedKeychainBindingsController] setValue:value forKeyPath:[NSString stringWithFormat:@"values.%@",defaultName]];
}

- (void)setString:(NSString *)value forKey:(NSString *)defaultName {
    [[INPDKeychainBindingsController sharedKeychainBindingsController] setValue:value forKeyPath:[NSString stringWithFormat:@"values.%@",defaultName]];
}

- (void)removeObjectForKey:(NSString *)defaultName {
    [[INPDKeychainBindingsController sharedKeychainBindingsController] setValue:nil forKeyPath:[NSString stringWithFormat:@"values.%@",defaultName]];
}

- (NSString *)stringForKey:(NSString *)defaultName {
    return (NSString *) [self objectForKey:defaultName];
}

@end
