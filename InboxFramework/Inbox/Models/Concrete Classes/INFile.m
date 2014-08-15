//
//  INAttachment.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INFile.h"
#import "INModelObject+Uniquing.h"
#import "INNamespace.h"
#import "INUploadFileTask.h"

@implementation INFile

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

+ (NSString *)resourceAPIName
{
    return @"files";
}

- (id)initWithImage:(UIImage*)image inNamespace:(INNamespace*)namespace
{
	return [self initWithFilename:@"image.jpg" mimetype:@"image/jpeg" andData:UIImageJPEGRepresentation(image, 0.85) andPreview: image inNamespace:namespace];
}

- (id)initWithFilename:(NSString*)filename mimetype:(NSString*)mimetype andData:(NSData*)data andPreview:(UIImage*)previewOrNil inNamespace:(INNamespace*)namespace
{
	NSAssert(data, @"You must provide attachment data.");
	NSAssert(filename, @"You must provide an attachment filename.");
	NSAssert(mimetype, @"You must provide an attachment mimetype.");
	NSAssert(namespace, @"You must provide an attachment namespace.");

	self = [super init];
	if (self) {
		self.namespaceID = [namespace ID];
		self.filename = filename;
		self.mimetype = mimetype;
		self.localPreview = previewOrNil;
		self.localDataPath = [[NSString stringWithFormat: @"~/Documents/%@.data", self.ID] stringByExpandingTildeInPath];
		[data writeToFile: _localDataPath atomically:NO];
		[INFile attachInstance: self];

	}
	return self;
}

- (UIImage*)localPreview
{
    if (_localPreview)
        return _localPreview;

    // TODO: Return previews
    return nil;
}

- (void)upload
{
	NSAssert(_localDataPath, @"Before calling -upload, you need to use one of the designated initializers to provide a reference to data to upload.");
	if ([self uploadTask])
        return;

	INUploadFileTask * upload = [[INUploadFileTask alloc] initWithModel: self];
	[[INAPIManager shared] queueTask: upload];
}

- (INUploadFileTask*)uploadTask
{
	for (INUploadFileTask * change in [[INAPIManager shared] taskQueue]) {
		if ([change isKindOfClass: [INUploadFileTask class]] && [[change model] isEqual: self])
			return change;
	}
	return nil;
}

- (void)getDataWithCallback:(AttachmentDownloadBlock)callback
{
	NSString * path = [NSString stringWithFormat:@"/n/%@/files/%@/download", self.namespaceID, self.ID];
	AFHTTPRequestOperation * op = [[INAPIManager shared].AF GET:path parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
		callback(nil, responseObject);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		callback(error, nil);
	}];
    [op setResponseSerializer: [AFHTTPResponseSerializer serializer]];
}

@end
