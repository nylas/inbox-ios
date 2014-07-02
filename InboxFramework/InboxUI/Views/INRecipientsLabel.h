//
//  INRecipientsLabel.h
//  BigSur
//
//  Created by Ben Gotow on 5/2/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface INRecipientsLabel : UIView
{
	NSMutableArray * _buttons;
	UIButton * _moreButton;
}
@property (nonatomic, strong) UIColor * textColor;
@property (nonatomic, strong) UIFont * textFont;
@property (nonatomic, assign) BOOL recipientsClickable;

- (void)setPrefixString:(NSString*)prefix andRecipients:(NSArray*)recipients includeMe:(BOOL)includeMe;

@end
