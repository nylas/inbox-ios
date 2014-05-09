//
//  TRAppDelegate.h
//  Triage
//
//  Created by Ben Gotow on 5/7/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TRViewController.h"

@interface TRAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) TRViewController * viewController;
@property (strong, nonatomic) UIWindow *window;

@end
