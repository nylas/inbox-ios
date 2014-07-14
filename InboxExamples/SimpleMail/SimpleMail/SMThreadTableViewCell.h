//
//  SMThreadTableViewCell.h
//  SimpleMail
//
//  Created by Ben Gotow on 7/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SMThreadTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel * dateLabel;
@property (nonatomic, strong) IBOutlet UILabel * fromLabel;
@property (nonatomic, strong) IBOutlet UILabel * bodyLabel;
@property (nonatomic, strong) IBOutlet UIImageView * unreadDot;

- (void)setThread:(INThread*)thread;

@end
