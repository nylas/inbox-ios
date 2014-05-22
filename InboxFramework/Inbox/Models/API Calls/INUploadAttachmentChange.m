//
//  INSaveAttachmentChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INUploadAttachmentChange.h"
#import "INAttachment.h"

@implementation INUploadAttachmentChange

- (NSURLRequest *)buildAPIRequest
{
	INAttachment * attachment = (INAttachment *)self.model;
	
    NSAssert(attachment, @"INUploadAttachmentChange asked to buildRequest with no model!");
	NSAssert([attachment namespaceID], @"INUploadAttachmentChange asked to buildRequest with no namespace!");
	NSAssert([attachment localDataPath], @"INUploadAttachmentChange asked to upload an attachment with no local data.");
	
    NSString * path = [NSString stringWithFormat:@"/n/%@/files", [attachment namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];

	return [[[INAPIManager shared] requestSerializer] multipartFormRequestWithMethod:@"POST" URLString:url parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
		NSURL * fileURL = [NSURL fileURLWithPath: [attachment localDataPath]];
		[formData appendPartWithFileURL:fileURL name:@"file" fileName:[attachment filename] mimeType:[attachment mimetype] error:NULL];
	} error:NULL];
}

@end
