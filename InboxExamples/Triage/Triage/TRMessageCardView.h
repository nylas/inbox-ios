//
//  TRMessageCardView.h
//  Triage
//
//  Created by Ben Gotow on 5/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "INPlaceholderTextView.h"

@interface TRMessageCardView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong) UIView * headersView;
@property (nonatomic, strong) UILabel * subjectLabel;
@property (nonatomic, strong) INRecipientsLabel * fromLabel;
@property (nonatomic, strong) INMessageContentView * bodyView;
@property (nonatomic, strong) INPlaceholderTextView * replyView;
@property (nonatomic, strong) UIButton * exitButton;

@property (nonatomic, assign) float angle;
@property (nonatomic, strong) INThread * thread;

- (void)setThread:(INThread*)thread;
- (void)setShowReplyView:(BOOL)showReply;
- (float)desiredHeight;

@end
