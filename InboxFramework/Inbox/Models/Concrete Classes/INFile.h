//
//  INAttachment.h
//  InboxFramework
//
//  Created by Ben Gotow on 5/21/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INModelObject.h"
#import "INAPIManager.h"

@class INUploadFileTask;

typedef void (^ AttachmentDownloadBlock)(NSError * error, NSData * data);

/** INAttachment represents a single attachment on an email message. Attachments
may be created, uploaded and attached to drafts, or fetched from the server for 
existing messages.
*/
@interface INFile : INModelObject

@property (nonatomic, strong) NSString * localDataPath;
@property (nonatomic, strong) UIImage * localPreview;
@property (nonatomic, strong) NSString * filename;
@property (nonatomic, strong) NSString * mimetype;

/**
Initialize an INAttachment with the provided image as a JPG. Images may be
compressed and/or downsized automatically if they are too large.

@param image The image to upload.

@param namespace The namespace to add this attachment in.

@return An initialized INAttachment object. To start uploading this attachment, you need
to call -upload.
*/
- (id)initWithImage:(UIImage*)image inNamespace:(INNamespace*)namespace;

/**
 Initialize an INAttachment with the arbitrary file data provided.
 
 @param filename The display filename of the attachment.
 @param mimetype The mimetype of the attachment, such as "image/jpeg" or "text/plain".
 @param data The attachment data.
 @param previewOrNil A small UIImage to use for displaying this attachment in your app.
 If you don't provide a preview image, subsequent requests for this attachment's localPreview
 may return nil.
 @param namespace The namespace to add this attachment in.
 
 @return An initialized INAttachment object. To start uploading this attachment, you need
 to call -upload.
 */
- (id)initWithFilename:(NSString*)filename mimetype:(NSString*)mimetype andData:(NSData*)data andPreview:(UIImage*)previewOrNil inNamespace:(INNamespace*)namespace;

/** 
 Start uploading this attachment in the background. To track the progress of the upload 
 operation, observe the INUploadAttachmentTask returned from -uploadTask for the 
 INTaskProgressNotification notification.
*/
- (void)upload;

/**
 @return The upload task that is currently trying to upload this attachment object. To track
 the progress of this upload, listen for INTaskProgressNotification notifications for this
 object.
*/
- (INUploadFileTask*)uploadTask;

/**
 Asynchronously fetches the attachment data from the server.

 @param callback The callback to invoke when attachment data has been successfully downloaded,
 or an error has occurred.
*/
- (void)getDataWithCallback:(AttachmentDownloadBlock)callback;

@end
