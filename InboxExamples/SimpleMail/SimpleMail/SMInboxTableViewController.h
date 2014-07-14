//
//  SMInboxTableViewController.h
//  SimpleMail
//
//  Created by Ben Gotow on 7/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SMInboxTableViewController : UITableViewController <INModelProviderDelegate>

@property (nonatomic, strong) INThreadProvider * threadProvider;

@end
