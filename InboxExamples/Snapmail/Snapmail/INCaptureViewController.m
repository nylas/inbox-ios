//
//  INCaptureViewController.m
//  Snapmail
//
//  Created by Ben Gotow on 6/16/14.
//  Copyright (c) 2014 Foundry 376, LLC. All rights reserved.
//

#import "INCaptureViewController.h"
#import "INContactsViewController.h"

@implementation INCaptureViewController

- (id)initWithThread:(INThread*)thread
{
	self = [super init];
	if (self) {
		_thread = thread;
		
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[_toggleSideButton setHidden: ![UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)toggleSideTapped:(id)sender
{
	if (_picker.cameraDevice == UIImagePickerControllerCameraDeviceFront)
		[_picker setCameraDevice: UIImagePickerControllerCameraDeviceRear];
	else
		[_picker setCameraDevice: UIImagePickerControllerCameraDeviceFront];
	
}

- (IBAction)cancelTapped:(id)sender
{
	[_picker dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)captureTapped:(id)sender
{
	[_picker takePicture];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage * img = [info objectForKey: UIImagePickerControllerOriginalImage];
    
	if (!_thread) {
        INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
		INContactsViewController * contacts = [[INContactsViewController alloc] initForSelectingContactInNamespace:namespace withCallback:^(INContact *object) {
            [self sendImage: img to:@[object]];
			[picker dismissViewControllerAnimated:NO completion:NULL];
			[picker dismissViewControllerAnimated:NO completion:NULL];
		}];
		UINavigationController * nav = [[UINavigationController alloc] initWithRootViewController: contacts];
		[picker presentViewController: nav animated: NO completion: NULL];

	} else {
        [self sendImage: img to:nil];
		[picker dismissViewControllerAnimated:YES completion:NULL];
	}
}

- (void)sendImage:(UIImage*)image to:(NSArray*)contacts
{
    INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
	INDraft * draft = nil;
	
	if (_thread) {
		draft = [[INDraft alloc] initInNamespace:namespace inReplyTo:_thread];
	} else {
		draft = [[INDraft alloc] initInNamespace:namespace];
		[draft setSubject: @"You've got a new snap!"];
	}

    INFile * file = [[INFile alloc] initWithImage:image inNamespace:namespace];
    [file upload];
    [draft addAttachment: file];
    
    if (contacts)
        [draft setTo: @[@{@"name": [[contacts firstObject] name], @"email": @"bengotow@gmail.com"}]];

    [draft send];

}

@end
