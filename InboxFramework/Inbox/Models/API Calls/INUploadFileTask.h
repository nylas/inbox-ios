//
//  INSaveAttachmentChange.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAPITask.h"

@interface INUploadFileTask : INAPITask

- (NSMutableArray *)waitingDrafts;

@end
