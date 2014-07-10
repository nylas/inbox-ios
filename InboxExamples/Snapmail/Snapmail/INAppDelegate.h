//
//  INAppDelegate.h
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 InboxApp, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INHomeViewController.h"

@interface INAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow * window;
@property (strong, nonatomic) INHomeViewController * viewController;

@end
