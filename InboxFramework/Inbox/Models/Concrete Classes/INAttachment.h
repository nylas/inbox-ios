//
//  INAttachment.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INAPIManager.h"
#import "INUploadAttachmentChange.h"

typedef void (^ AttachmentDownloadBlock)(NSError * error, NSData * data);

@interface INAttachment : INModelObject

@property (nonatomic, strong) NSString * localDataPath;
@property (nonatomic, strong) UIImage * localPreview;
@property (nonatomic, strong) NSString * filename;
@property (nonatomic, strong) NSString * mimetype;

- (id)initWithImage:(UIImage*)image inNamespace:(INNamespace*)namespace;
- (id)initWithFilename:(NSString*)filename mimetype:(NSString*)mimetype andData:(NSData*)data andPreview:(UIImage*)previewOrNil inNamespace:(INNamespace*)namespace;

- (void)upload;
- (INUploadAttachmentChange*)uploadTask;

@end
