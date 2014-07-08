//
//  TRMessageCardView.m
//  Triage
//
//  Created by Ben Gotow on 5/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "TRMessageCardView.h"

#define INSET 8

@implementation TRMessageCardView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setBackgroundColor: [UIColor colorWithWhite:1 alpha:1]];
        
        [[self layer] setShadowOffset: CGSizeMake(0, 2)];
        [[self layer] setShadowOpacity: 0.2];
        [[self layer] setShadowRadius: 3];
        
        _bodyView = [[INMessageContentView alloc] initWithFrame: CGRectMake(0,0, frame.size.width - INSET * 2, 1)];
		[_bodyView setContentMargin: UIEdgeInsetsMake(INSET, INSET, INSET, INSET)];
        [[_bodyView scrollView] setScrollIndicatorInsets: UIEdgeInsetsZero];
        [[_bodyView scrollView] setDelegate: self];
        [_bodyView setUserInteractionEnabled:NO];
        [self addSubview: _bodyView];

        _headersView = [[UIView alloc] initWithFrame: CGRectZero];
        [_headersView setBackgroundColor: [UIColor colorWithRed:229.0/255.0 green:244/255.0 blue:247/255.0 alpha:1]];
        [[_headersView layer] setShadowOffset: CGSizeMake(0, 1)];
        [[_headersView layer] setShadowRadius: 2];
        [self addSubview: _headersView];
        
        _subjectLabel = [[UILabel alloc] initWithFrame: CGRectZero];
        [_subjectLabel setFont: [UIFont fontWithName:@"HelveticaNeue-Light" size:20]];
        [_subjectLabel setNumberOfLines: 2];
        [self addSubview: _subjectLabel];

        _fromLabel = [[INRecipientsLabel alloc] initWithFrame: CGRectZero];
        [_fromLabel setTextFont: [UIFont fontWithName:@"HelveticaNeue-Bold" size:13]];
        [_fromLabel setTextColor: [UIColor colorWithRed:0 green:150.0/255.0 blue:178.0/255.0 alpha:1]];
        [self addSubview: _fromLabel];
        
        _replyView = [[INPlaceholderTextView alloc] initWithFrame: CGRectMake(0, 0, 320, 20)];
        [_replyView setPlaceholder: @"Compose a reply..."];
        [_replyView setPlaceholderColor: [UIColor lightGrayColor]];
        [_replyView setEnablesReturnKeyAutomatically:YES];
        [_replyView setReturnKeyType: UIReturnKeySend];
        [_replyView setFont: [UIFont systemFontOfSize: 14]];
        [_replyView setHidden: YES];
        [_replyView setBackgroundColor: [UIColor colorWithWhite:0.95 alpha:1]];
        [self addSubview: _replyView];
        
        _exitButton = [UIButton buttonWithType: UIButtonTypeCustom];
        [[_exitButton layer] setBorderColor: [[UIColor colorWithWhite:0 alpha:0.25] CGColor]];
        [[_exitButton layer] setBorderWidth: 0.5];
        [[_exitButton layer] setCornerRadius: 4];
        [[_exitButton titleLabel] setFont: [UIFont boldSystemFontOfSize: 13]];
        [_exitButton setTitleColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
        [_exitButton setTitleColor:[UIColor colorWithWhite:0 alpha:0.7] forState:UIControlStateHighlighted];
        [_exitButton setTitle:@"✕" forState:UIControlStateNormal];
        [_exitButton setHidden: YES];
        [self addSubview: _exitButton];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [[self layer] setShadowPath: CGPathCreateWithRect(self.bounds, NULL)];

    float w = self.bounds.size.width - INSET * 2;

    [UIView setAnimationsEnabled: NO];
    if ([_exitButton isHidden])
        [_subjectLabel setFrame: CGRectMake(INSET, INSET, w, 40)];
    else
        [_subjectLabel setFrame: CGRectMake(INSET, INSET, w - 23, 40)];
    [_subjectLabel sizeToFit];
    [UIView setAnimationsEnabled: YES];
    
    [_exitButton setFrame: CGRectMake( self.bounds.size.width - 23 - INSET, INSET + 2, 23, 23)];
    [_fromLabel setFrame: CGRectMake(INSET, INSET + _subjectLabel.frame.size.height, w, 25)];
    
    float y = INSET + _fromLabel.frame.size.height + _subjectLabel.frame.size.height;
    [_headersView setFrame: CGRectMake(0, 0, self.bounds.size.width, y)];
    [[_headersView layer] setShadowPath: CGPathCreateWithRect(_headersView.bounds, NULL)];
    
    float remainingHeight = self.bounds.size.height - INSET - y;
    
    if ([_replyView isHidden]) {
        [_bodyView setFrame: CGRectMake(0, y + 0, self.bounds.size.width, remainingHeight)];
        [_replyView setFrame: CGRectMake(INSET, y + INSET + remainingHeight, w, 1)];
        [[_bodyView scrollView] setScrollEnabled: NO];
        
    } else {
        float replyHeight = fmaxf(28, fminf(100, [_replyView contentSize].height));
        float bodyHeight = fminf([_bodyView bodyHeight], remainingHeight - (replyHeight + INSET * 2));
        [_bodyView setFrame: CGRectMake(0, y, self.bounds.size.width, bodyHeight)];
        [_replyView setFrame: CGRectMake(INSET, y + INSET + bodyHeight + INSET, w, replyHeight)];
		
		BOOL largerThanFrame = ([_bodyView frame].size.height < [_bodyView bodyHeight] - 1.0);
        [[_bodyView scrollView] setScrollEnabled: largerThanFrame];
    }
}

- (float)desiredHeight
{
    if ([_replyView isHidden])
        return [_bodyView bodyHeight] + _bodyView.frame.origin.y + INSET;
    else
        return [_bodyView bodyHeight] + _bodyView.frame.origin.y + INSET * 3 + 32;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame: frame];
    [self layoutSubviews];
}

- (void)setThread:(INThread*)thread
{
	_thread = thread;
	
    NSString * messageID = [[thread messageIDs] lastObject];
    INMessage * message = [INMessage instanceWithID:messageID inNamespaceID:[thread namespaceID]];
    [message setNamespaceID: [thread namespaceID]];
    
    if (![message body]) {
        [_bodyView setAlpha: 0];
        [message reload:^(BOOL success, NSError *error) {
            [self populateWithThread:thread andMessage:message];
        }];
    } else {
        [self populateWithThread:thread andMessage:message];
    }
    
    [_subjectLabel setText: [thread subject]];
    [self setNeedsLayout];
}

- (void)populateWithThread:(INThread*)thread andMessage:(INMessage*)message
{
    [_bodyView setContent: [message body]];

    // figure out the name of the sender
    NSString * from = [[[message from] firstObject] objectForKey:@"name"];
    if (![from length])
        from = [[[message from] firstObject] objectForKey: @"email"];
    from = [from stringByAppendingString: @" to "];
    
    NSMutableArray * others = [[thread participants] mutableCopy];
    [others removeObject: [[message from] firstObject]];
    [_fromLabel setPrefixString:from andRecipients:others includeMe:YES];

    if ([_bodyView alpha] == 0) {
        [UIView animateWithDuration:0.3 animations:^{
            [_bodyView setAlpha: 1];
        }];
    }
}

- (void)setShowReplyView:(BOOL)showReply
{
    [_replyView setHidden: !showReply];
    [_exitButton setHidden: !showReply];
    [self setNeedsLayout];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentOffset.y > 0) {
        [self setHeaderShadowOpacity: 0.15];
    } else {
        [self setHeaderShadowOpacity: 0];
    }
}

- (void)setHeaderShadowOpacity:(float)opacity
{
    if ([[_headersView layer] shadowOpacity] == opacity)
        return;
    
    [_headersView.layer addAnimation:((^ {
        CABasicAnimation *transition = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        transition.fromValue = (id)@([[_headersView layer] shadowOpacity]);
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.duration = 0.2;
        return transition;
    })()) forKey:@"shadowOpacity"];
    [[_headersView layer] setShadowOpacity: opacity];

}
@end
