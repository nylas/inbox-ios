//
//  TRMessageActionButton.m
//  Triage
//
//  Created by Ben Gotow on 5/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "TRMessageActionButton.h"

@implementation TRMessageActionButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib
{
    _selectedView = [[UIView alloc] initWithFrame: self.bounds];
    [[_selectedView layer] setCornerRadius: self.bounds.size.width / 2];
    [_selectedView setBackgroundColor: [self tintColor]];
    [self insertSubview:_selectedView belowSubview:self.titleLabel];
    [_selectedView setTransform: CGAffineTransformMakeScale(0.1, 0.1)];
    [_selectedView setAlpha: 0];

    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
}

- (void)setSelected:(BOOL)selected
{
    if (self.selected == selected)
        return;
    
    [super setSelected: selected];
    
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.45 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (selected == NO) {
            [_selectedView setTransform: CGAffineTransformMakeScale(0.1, 0.1)];
            [_selectedView setAlpha: 0];
        } else {
            [_selectedView setTransform: CGAffineTransformMakeScale(1.1, 1.1)];
            [_selectedView setAlpha: 1];
        }
    } completion:NULL];
}

@end
