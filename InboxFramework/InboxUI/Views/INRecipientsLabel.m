//
//  INRecipientsLabel.m
//  BigSur
//
//  Created by Ben Gotow on 5/2/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INRecipientsLabel.h"
#import "UIView+FrameAdditions.h"
#import "INAPIManager.h"

@implementation INRecipientsLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		[self setup];
    }
    return self;
}

- (void)awakeFromNib
{
	[self setup];
}

- (void)setup
{
	if (!_textColor)
		_textColor = [UIColor blackColor];
    if (!_textFont)
		_textFont = [UIFont systemFontOfSize: 14];
	_moreButton = [UIButton buttonWithType: UIButtonTypeCustom];

	[self addSubview: _moreButton];
    [self setBackgroundColor: [UIColor clearColor]];
}

- (void)setPrefixString:(NSString*)prefix andRecipients:(NSArray*)recipients includeMe:(BOOL)includeMe
{
	if ([recipients count] == 0)
		recipients = @[@{@"name":@"(No Recipients)", @"email":@""}];

	NSArray * youAddresses = [[INAPIManager shared] namespaceEmailAddresses];
	
	[_buttons makeObjectsPerformSelector: @selector(removeFromSuperview)];
	_buttons = [[NSMutableArray alloc] init];
	
	[_moreButton setTitleColor:_textColor forState:UIControlStateNormal];
	[[_moreButton titleLabel] setFont: _textFont];

	BOOL firstNamesOnly = ([recipients count] > 2);
	BOOL includedMe = NO;
	
	NSMutableArray * names = [NSMutableArray array];
	for (NSDictionary * recipient in recipients) {
		NSString * name = recipient[@"name"];
		
		// show "Me" instead of your name
		if ([youAddresses containsObject: recipient[@"email"]]) {
			if (includedMe)
				continue;
			includedMe = YES;
			
			if (includeMe)
				name = @"Me";
			else
				continue;
		}

		// show only a first name if there are more than 2 recipients
		if (firstNamesOnly) {
			// Parse names like "McConnel, Jenny T."
			BOOL commaSeparatedParts = ([name rangeOfString: @","].location != NSNotFound);
			if (commaSeparatedParts)
				name = [name substringFromIndex: [name rangeOfString:@","].location+1];
			
			// Parse out the first word from the name
			name = [name stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			BOOL twoParts = ([name rangeOfString:@" "].location != NSNotFound);
			if (twoParts)
				name = [name substringToIndex: [name rangeOfString: @" "].location];
		}
		
		// trim whitespace from names
		name = [name stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
		
		// use email address of recipeint if name is not provided
		if ([name length] == 0)
			name = [recipient objectForKey: @"email"];
		
        if (prefix) {
            name = [prefix stringByAppendingString: name];
            prefix = nil;
        }
        
		if ([name isEqualToString: @"Me"])
			[names insertObject:name atIndex:0];
		else
			[names addObject: name];
	}
	
	for (int ii = 0; ii < [names count]; ii ++) {
		NSString * name = [names objectAtIndex: ii];
		if (ii == [names count] - 2)
			name = [name stringByAppendingString: @" & "];
		else if (ii < (int)[names count] - 2)
			name = [name stringByAppendingString: @", "];
		
		UIButton * b = [UIButton buttonWithType: UIButtonTypeCustom];
		[b setTitle:name forState:UIControlStateNormal];
		[b setTitleColor: _textColor forState:UIControlStateNormal];
		[b setTitleColor: _textColor forState:UIControlStateDisabled];
		[[b titleLabel] setFont: _textFont];
		[[b titleLabel] setLineBreakMode: NSLineBreakByTruncatingTail];
		[_buttons addObject: b];
		[self addSubview: b];
	}
	
	[self setNeedsLayout];
}

- (void)layoutSubviews
{
	[super layoutSubviews];

	float x = 0;
	BOOL hide = NO;
	int hidden = 0;
	
    NSMutableArray * visible = [NSMutableArray array];
    
	for (UIButton * b in _buttons) {
		CGSize size = [[b titleForState: UIControlStateNormal] sizeWithAttributes: @{NSFontAttributeName: [[b titleLabel] font]}];
		[b setFrame: CGRectMake(x, 0, fminf(self.frame.size.width, size.width), self.frame.size.height)];
		
		if (x + [b frame].size.width > self.frame.size.width)
			hide = YES;
		
		BOOL isFirstItem = (x == 0);
		
        [b setHidden:NO];
		if (hide && !isFirstItem) {
			[b setHidden:YES];
			hidden ++;
			continue;
		} else {
			x += [b frame].size.width;
		}
        
        if ([b isHidden] == NO)
            [visible addObject: b];
	}
	
	[_moreButton setHidden: (hidden == 0)];

    if ([_moreButton isHidden] == NO) {
        NSString * moreLabel = [NSString stringWithFormat: @"%d more...", hidden];
        [_moreButton setTitle:moreLabel forState:UIControlStateNormal];
        [_moreButton sizeToFit];
        
        UIButton * lastButton = [visible lastObject];
        if (x + [_moreButton frame].size.width > self.frame.size.width) {
            float maxX = self.frame.size.width - [_moreButton frame].size.width;
            [lastButton in_setFrameWidth: lastButton.frame.size.width - (x - maxX)];
            x = maxX;
        }
        
        [_moreButton in_setFrameHeight: self.frame.size.height];
        [_moreButton in_setFrameX: x];
    }
}
@end
