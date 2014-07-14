//
//  SMThreadTableViewCell.m
//  SimpleMail
//
//  Created by Ben Gotow on 7/8/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "SMThreadTableViewCell.h"

static NSDateFormatter * threadDateFormatter;

@implementation SMThreadTableViewCell

- (void)setThread:(INThread *)thread
{
	if (!threadDateFormatter) {
		threadDateFormatter = [[NSDateFormatter alloc] init];
		[threadDateFormatter setDateStyle: NSDateFormatterShortStyle];
		[threadDateFormatter setTimeStyle: NSDateFormatterShortStyle];
	}
	
	// display subject and snippet Gmail-style
	NSString * body = [NSString stringWithFormat:@"%@—%@", [thread subject], [thread snippet]];
	[[self bodyLabel] setText: body];

	// format dates nicely
	NSString * date = [threadDateFormatter stringFromDate: [thread lastMessageDate]];
	[[self dateLabel] setText: date];

	[[self unreadDot] setHidden: ![thread unread]];
	
	// collect the names of the participants, except for ourselves
	// to populate the top label of the cell
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
	NSMutableArray * names = [NSMutableArray array];
	for (NSDictionary * participant in [thread participants]) {
		if ([participant[@"email"] isEqualToString: [namespace emailAddress]])
			continue;
		
		if ([participant[@"name"] length])
			[names addObject: participant[@"name"]];
		else
			[names addObject: participant[@"email"]];
	}
	
	[[self fromLabel] setText: [names componentsJoinedByString:@", "]];
}

@end
