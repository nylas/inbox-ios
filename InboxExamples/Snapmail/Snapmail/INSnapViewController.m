//
//  INSnapViewController.m
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 InboxApp, Inc. All rights reserved.
//

#import "INSnapViewController.h"
#import "INHomeViewController.h"

@implementation INSnapViewController

- (id)initWithThread:(INThread*)thread
{
	self = [super init];
	if (self) {
		_provider = [thread newMessageProvider];
		_provider.delegate = self;
		[_provider refresh];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_errorLabel setText: @""];
	[_spinner startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_timer invalidate];
    _timer = nil;
}

- (void)displaySnapImage
{
	// TODO iterate over snaps and find the oldest unread one...
	INMessage * message = nil;
	for (INMessage * msg in [_provider items]) {
		if ([[msg attachmentIDs] count] > 0)
			message = msg;
	}

    if (message == nil)
        return;
    
	INFile * file = [[message attachments] firstObject];
	if (file == nil)
		[(INHomeViewController*)self.parentViewController dismissSnapViewController];
		
	[file getDataWithCallback:^(NSError *error, NSData *data) {
		[_spinner stopAnimating];
		if (error) {
			[_errorLabel setText: [error localizedDescription]];
			return;
		}
		
        [message markAsRead];
		
		UIImage * img = [UIImage imageWithData: data];
		[_imageView setImage: img];
		[_timeLabel setText: @"5"];
		
		[_timer invalidate];
		_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(countdown) userInfo:nil repeats:YES];
	}];
}

- (void)countdown
{
	int timeRemaining = [[_timeLabel text] intValue];
	timeRemaining -= 1;
	
	if (timeRemaining == 0) {
		[_imageView setImage: nil];
		[self displaySnapImage];
	} else {
		[_timeLabel setText: [NSString stringWithFormat:@"%d", timeRemaining]];
	}
}

- (void)providerDataChanged:(INModelProvider *)provider
{
    [self displaySnapImage];
}

- (void)provider:(INModelProvider *)provider dataFetchFailed:(NSError *)error
{
	[_errorLabel setText: [error localizedDescription]];
}

@end
