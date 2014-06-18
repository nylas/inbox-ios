//
//  INSnapViewController.h
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 Foundry 376, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface INSnapViewController : UIViewController <INModelProviderDelegate>

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView * spinner;
@property (nonatomic, weak) IBOutlet UIImageView * imageView;
@property (nonatomic, weak) IBOutlet UILabel * errorLabel;
@property (nonatomic, weak) IBOutlet UILabel * timeLabel;

@property (nonatomic, strong) NSTimer * timer;
@property (nonatomic, strong) INMessageProvider * provider;

- (id)initWithThread:(INThread*)thread;

@end
