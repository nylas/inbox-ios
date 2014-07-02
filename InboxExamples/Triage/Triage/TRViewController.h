//
//  TRViewController.h
//  Triage
//
//  Created by Ben Gotow on 5/7/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TRMessageActionButton.h"

@interface TRViewController : UIViewController <UIDynamicAnimatorDelegate, INModelProviderDelegate, UITextViewDelegate>

@property (nonatomic, weak) IBOutlet UIButton * messageDismissView;
@property (weak, nonatomic) IBOutlet TRMessageActionButton *saveButton;
@property (weak, nonatomic) IBOutlet TRMessageActionButton *archiveButton;
@property (weak, nonatomic) IBOutlet UIView *emptyView;
@property (weak, nonatomic) IBOutlet UILabel *emptyTextLabel;

@property (nonatomic, strong) UIPanGestureRecognizer * messageDragRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer * messageDTapRecognizer;
@property (nonatomic, strong) NSMutableArray * messageViews;
@property (nonatomic, strong) UIDynamicAnimator * animator;

@property (nonatomic, strong) INModelProvider * threadProvider;

@end
