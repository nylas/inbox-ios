//
//  INViewController.h
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 InboxApp, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INSnapViewController.h"
#import "INCaptureViewController.h"

@interface INHomeViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, INModelProviderDelegate>

@property (weak, nonatomic) IBOutlet UITableView * tableView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) UIRefreshControl * tableRefreshControl;

@property (nonatomic, strong) INSnapViewController * snapController;
@property (nonatomic, strong) INCaptureViewController * captureController;

@property (nonatomic, strong) INModelProvider * sendingProvider;
@property (nonatomic, strong) INThreadProvider * threadProvider;

@property (nonatomic, strong) INMessageProvider * messageProvider;

- (void)dismissSnapViewController;

@end
