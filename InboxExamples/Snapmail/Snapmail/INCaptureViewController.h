//
//  INCaptureViewController.h
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 InboxApp, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface INCaptureViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) INThread * thread;
@property (nonatomic, strong) UIImagePickerController * picker;
@property (weak, nonatomic) IBOutlet UIButton *toggleSideButton;

- (id)initWithThread:(INThread*)thread;

@end
