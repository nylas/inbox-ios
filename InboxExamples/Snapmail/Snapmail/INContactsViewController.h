//
//  INContactsViewController.h
//  BigSur
//
//  Created by Ben Gotow on 5/5/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ ContactSelectionBlock)(NSArray * contacts);

@interface INContactsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, INModelProviderDelegate>

@property (nonatomic, strong) INNamespace * namespace;
@property (nonatomic, strong) INModelProvider * contactsProvider;
@property (nonatomic, strong) ContactSelectionBlock contactSelectionCallback;
@property (nonatomic, weak) IBOutlet UITableView * tableView;

- (id)initForSelectingContactInNamespace:(INNamespace*)ns withCallback:(ContactSelectionBlock)block;

@end
