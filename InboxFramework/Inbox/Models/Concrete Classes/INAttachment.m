//
//  INAttachment.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INAttachment.h"
#import "INModelObject+Uniquing.h"
#import "INNamespace.h"
#import "INUploadAttachmentTask.h"

@implementation INAttachment

+ (NSMutableDictionary *)resourceMapping
{
	NSMutableDictionary * mapping = [super resourceMapping];
	[mapping addEntriesFromDictionary: @{
		 @"filename": @"filename",
		 @"mimetype": @"mimetype",

		 @"localDataPath": @"__localDataPath",
	}];
	return mapping;
}

- (id)initWithImage:(UIImage*)image inNamespace:(INNamespace*)namespace
{
	return [self initWithFilename:@"image.jpg" mimetype:@"image/jpeg" andData:UIImageJPEGRepresentation(image, 0.85) andPreview: image inNamespace:namespace];
}

- (id)initWithFilename:(NSString*)filename mimetype:(NSString*)mimetype andData:(NSData*)data andPreview:(UIImage*)previewOrNil inNamespace:(INNamespace*)namespace
{
	self = [super init];
	if (self) {
		self.namespaceID = [namespace ID];
		self.filename = filename;
		self.mimetype = mimetype;
		self.localPreview = previewOrNil;
		self.localDataPath = [[NSString stringWithFormat: @"~/Documents/%@.data", self.ID] stringByExpandingTildeInPath];
		[data writeToFile: _localDataPath atomically:NO];
		[INAttachment attachInstance: self];
		
	}
	return self;
}

- (void)upload
{
	INUploadAttachmentTask * upload = [[INUploadAttachmentTask alloc] initWithModel: self];
	[[INAPIManager shared] queueTask: upload];
}

- (INUploadAttachmentTask*)uploadTask
{
	for (INUploadAttachmentTask * change in [[INAPIManager shared] taskQueue]) {
		if ([change isKindOfClass: [INUploadAttachmentTask class]] && [[change model] isEqual: self])
			return change;
	}
	return nil;
}

- (void)getDataWithCallback:(AttachmentDownloadBlock)callback
{
	NSString * path = [NSString stringWithFormat:@"/n/%@/files/%@/download", self.namespaceID, self.ID];
	[[INAPIManager shared] GET:path parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		callback(nil, responseObject);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		callback(error, nil);
	}];
}

@end
