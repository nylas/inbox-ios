//
//  INMessageContentView.h
//  BigSur
//
//  Created by Ben Gotow on 5/23/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol INMessageContentViewDelegate <NSObject>

- (void)messageContentViewSizeDetermined:(CGSize)size;

@end

@interface INMessageContentView : UIView <UIWebViewDelegate>
{
    NSString * _content;
    BOOL _contentLoadCompleted;
}

@property (nonatomic, weak) IBOutlet NSObject<INMessageContentViewDelegate> * delegate;

@property (nonatomic, strong) UIColor * tintColor;
@property (nonatomic, strong) UIWebView * webView;
@property (nonatomic, strong) UITextView * textView;
@property (nonatomic, assign) UIEdgeInsets contentMargin;
@property (nonatomic, strong) NSURL * contentBaseURL;

- (void)clearContent;
- (void)setContent:(NSString*)content;
- (void)setContentMargin:(UIEdgeInsets)margin;

- (float)bodyHeight;
- (UIScrollView*)scrollView;

@end
