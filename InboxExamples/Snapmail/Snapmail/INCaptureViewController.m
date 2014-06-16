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
	INNamespace * namespace = [[[INAPIManager shared] namespaces] firstObject];
	INDraft * draft = nil;
	
	if (_thread) {
		draft = [[INDraft alloc] initInNamespace:namespace inReplyTo:_thread];
	} else {
		draft = [[INDraft alloc] initInNamespace:namespace];
		[draft setSubject: @"You've got a snap!"];
	}

	INFile * file = [[INFile alloc] initWithImage:[info objectForKey: UIImagePickerControllerOriginalImage] inNamespace:namespace];
	[file upload];
	[draft addAttachment: file];
	
	if ([draft to] == nil) {
		INContactsViewController * contacts = [[INContactsViewController alloc] initForSelectingContactInNamespace:namespace withCallback:^(INContact *object) {
			[draft setTo: @[@{@"name": [object name], @"email": [object email]}]];
			[draft send];
			[picker dismissViewControllerAnimated:YES completion:NULL];
		}];
		UINavigationController * nav = [[UINavigationController alloc] initWithRootViewController: contacts];
		[picker presentViewController: nav animated: NO completion: NULL];
	} else {
		[draft send];
		[picker dismissViewControllerAnimated:YES completion:NULL];
	}
}

@end
